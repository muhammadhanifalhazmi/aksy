package com.example.aksy

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothDevice
import android.bluetooth.BluetoothManager
import android.bluetooth.BluetoothSocket
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

class BluetoothPrinterPlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.example.aksy/printer"
        private const val PERMISSION_REQUEST_CODE = 0xB7
        private const val CHUNK_SIZE = 256
        private const val CHUNK_DELAY_MS = 20L
        private const val SETTLE_AFTER_CONNECT_MS = 300L
        private const val STATUS_TIMEOUT_MS = 600
        private const val OFFLINE_BIT = 0x08

        private val SPP_UUIDS = listOf(
            "00001101-0000-1000-8000-00805F9B34FB",
            "0000FF00-0000-1000-8000-00805F9B34FB",
            "0000FFE0-0000-1000-8000-00805F9B34FB",
            "0000110E-0000-1000-8000-00805F9B34FB"
        )
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val worker = Executors.newSingleThreadExecutor()
    private val readPool = Executors.newCachedThreadPool()
    private val handler = Handler(Looper.getMainLooper())
    private var socket: BluetoothSocket? = null
    private var activeUuid: String? = null
    private var pendingPermission: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        closeSocket()
        worker.shutdown()
        readPool.shutdownNow()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermissions" -> result.success(hasPermissions())
            "requestPermissions" -> requestPermissions(result)
            "isBluetoothAvailable" -> result.success(isBluetoothAvailable())
            "openBluetoothSettings" -> {
                openBluetoothSettings()
                result.success(true)
            }
            "listPairedDevices" -> listPairedDevices(result)
            "connect" -> connect(call.argument<String>("address"), result)
            "disconnect" -> {
                closeSocket()
                result.success(true)
            }
            "isConnected" -> result.success(socket?.isConnected == true)
            "print" -> print(call, result)
            else -> result.notImplemented()
        }
    }

    fun onRequestPermissionsResult(
        requestCode: Int,
        grantResults: IntArray
    ): Boolean {
        if (requestCode != PERMISSION_REQUEST_CODE) return false
        val pending = pendingPermission ?: return false
        pendingPermission = null
        pending.success(grantResults.isNotEmpty() && hasPermissions())
        return true
    }

    private fun requiredPermissions(): Array<String> {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            arrayOf(
                Manifest.permission.BLUETOOTH_SCAN,
                Manifest.permission.BLUETOOTH_CONNECT
            )
        } else {
            arrayOf(Manifest.permission.ACCESS_FINE_LOCATION)
        }
    }

    private fun hasPermissions(): Boolean {
        return requiredPermissions().all {
            ContextCompat.checkSelfPermission(context, it) == PackageManager.PERMISSION_GRANTED
        }
    }

    private fun requestPermissions(result: MethodChannel.Result) {
        if (hasPermissions()) {
            result.success(true)
            return
        }
        val activity = context as? Activity
        if (activity == null) {
            result.success(false)
            return
        }
        pendingPermission = result
        ActivityCompat.requestPermissions(activity, requiredPermissions(), PERMISSION_REQUEST_CODE)
    }

    private fun adapter() = (context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager)?.adapter

    private fun isBluetoothAvailable(): Boolean = hasPermissions() && adapter()?.isEnabled == true

    private fun openBluetoothSettings() {
        context.startActivity(
            Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )
    }

    private fun listPairedDevices(result: MethodChannel.Result) {
        if (!hasPermissions()) {
            result.error("permission_denied", "Izin Bluetooth belum diberikan", null)
            return
        }
        val devices = adapter()?.bondedDevices.orEmpty()
            .map { mapOf("name" to (it.name ?: "Printer"), "address" to it.address) }
            .sortedBy { it["name"] as String }
        result.success(devices)
    }

    private fun connect(address: String?, result: MethodChannel.Result) {
        if (address.isNullOrBlank()) {
            result.error("invalid_address", "Alamat printer tidak valid", null)
            return
        }
        if (!hasPermissions()) {
            result.error("permission_denied", "Izin Bluetooth belum diberikan", null)
            return
        }
        val device = adapter()?.bondedDevices?.firstOrNull { it.address == address }
        if (device == null) {
            result.error("not_paired", "Printer belum dipairingkan dengan perangkat ini", null)
            return
        }
        worker.execute {
            closeSocket()
            adapter()?.cancelDiscovery()
            val failures = mutableListOf<String>()

            for (uuid in SPP_UUIDS) {
                var candidate: BluetoothSocket? = null
                try {
                    candidate = device.createRfcommSocketToServiceRecord(UUID.fromString(uuid))
                    candidate.connect()
                    Thread.sleep(SETTLE_AFTER_CONNECT_MS)

                    if (queryStatus(candidate) == null) {
                        closeQuietly(candidate)
                        failures += "${shortUuid(uuid)} tidak merespons"
                        continue
                    }

                    socket = candidate
                    activeUuid = uuid
                    postSuccess(result, mapOf("uuid" to uuid))
                    return@execute
                } catch (error: Exception) {
                    closeQuietly(candidate)
                    failures += "${shortUuid(uuid)}: ${error.message ?: "gagal"}"
                }
            }

            postError(
                result,
                "connect_failed",
                "Printer tidak merespons pada channel mana pun. " +
                    "Pastikan printer menyala dan sudah pairing.",
                failures.joinToString(" | ")
            )
        }
    }

    private fun print(call: MethodCall, result: MethodChannel.Result) {
        val bytes = call.argument<ByteArray>("bytes")
        if (bytes == null || bytes.isEmpty()) {
            result.error("empty_payload", "Data cetak kosong", null)
            return
        }
        val active = socket
        if (active == null || !active.isConnected) {
            result.error("not_connected", "Printer belum terhubung", null)
            return
        }
        worker.execute {
            try {
                val output = active.outputStream
                var offset = 0
                while (offset < bytes.size) {
                    val end = minOf(offset + CHUNK_SIZE, bytes.size)
                    output.write(bytes, offset, end - offset)
                    output.flush()
                    offset = end
                    if (offset < bytes.size) Thread.sleep(CHUNK_DELAY_MS)
                }
                Thread.sleep(SETTLE_AFTER_CONNECT_MS)

                val offline = isOffline(active)
                if (offline) {
                    postError(result, "printer_offline", "Printer menjadi offline saat mencetak")
                } else {
                    postSuccess(result, mapOf("bytes" to bytes.size, "uuid" to activeUuid))
                }
            } catch (error: Exception) {
                closeSocket()
                postError(
                    result,
                    "print_failed",
                    error.message ?: "Gagal mengirim data ke printer",
                    activeUuid
                )
            }
        }
    }

    private fun isOffline(target: BluetoothSocket): Boolean {
        val status = queryStatus(target) ?: return false
        return (status.toInt() and OFFLINE_BIT) != 0
    }

    private fun queryStatus(target: BluetoothSocket): Byte? {
        try {
            target.outputStream.write(byteArrayOf(0x10, 0x04, 0x01))
            target.outputStream.flush()
        } catch (_: Exception) {
            return null
        }
        val pending = readPool.submit<Byte?> {
            try {
                val response = target.inputStream.read()
                if (response < 0) null else response.toByte()
            } catch (_: Exception) {
                null
            }
        }
        return try {
            pending.get(STATUS_TIMEOUT_MS.toLong(), TimeUnit.MILLISECONDS)
        } catch (_: Exception) {
            pending.cancel(true)
            null
        }
    }

    private fun shortUuid(uuid: String): String = uuid.substring(0, 8).uppercase()

    private fun closeQuietly(target: BluetoothSocket?) {
        try {
            target?.close()
        } catch (_: Exception) {
        }
    }

    private fun closeSocket() {
        closeQuietly(socket)
        socket = null
        activeUuid = null
    }

    private fun postSuccess(result: MethodChannel.Result, value: Any? = true) {
        handler.post { result.success(value) }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String, details: Any? = null) {
        handler.post { result.error(code, message, details) }
    }
}
