package com.example.aksy

import android.Manifest
import android.app.Activity
import android.bluetooth.BluetoothAdapter
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

class BluetoothPrinterPlugin(
    private val context: Context,
    messenger: BinaryMessenger
) : MethodChannel.MethodCallHandler {

    companion object {
        const val CHANNEL = "com.example.aksy/printer"
        private const val SPP_UUID = "00001101-0000-1000-8000-00805F9B34FB"
        private const val PERMISSION_REQUEST_CODE = 0xB7
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val worker = Executors.newSingleThreadExecutor()
    private val handler = Handler(Looper.getMainLooper())
    private var socket: BluetoothSocket? = null
    private var pendingPermission: MethodChannel.Result? = null

    init {
        channel.setMethodCallHandler(this)
    }

    fun dispose() {
        closeSocket()
        worker.shutdown()
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
        ActivityCompat.requestPermissions(
            activity,
            requiredPermissions(),
            PERMISSION_REQUEST_CODE
        )
    }

    private fun adapter(): BluetoothAdapter? {
        val manager = context.getSystemService(Context.BLUETOOTH_SERVICE) as? BluetoothManager
        return manager?.adapter ?: BluetoothAdapter.getDefaultAdapter()
    }

    private fun isBluetoothAvailable(): Boolean {
        return hasPermissions() && adapter()?.isEnabled == true
    }

    private fun openBluetoothSettings() {
        val intent = Intent(Settings.ACTION_BLUETOOTH_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    private fun listPairedDevices(result: MethodChannel.Result) {
        if (!hasPermissions()) {
            result.error("permission_denied", "Izin Bluetooth belum diberikan", null)
            return
        }
        val devices = adapter()?.bondedDevices.orEmpty()
            .map { device ->
                mapOf(
                    "name" to (device.name ?: "Printer"),
                    "address" to device.address
                )
            }
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
            try {
                closeSocket()
                val socket = device.createRfcommSocketToServiceRecord(
                    UUID.fromString(SPP_UUID)
                )
                adapter()?.cancelDiscovery()
                socket.connect()
                this.socket = socket
                postSuccess(result)
            } catch (error: Exception) {
                closeSocket()
                postError(
                    result,
                    "connect_failed",
                    error.message ?: "Gagal terhubung ke printer"
                )
            }
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
                output.write(bytes)
                output.flush()
                postSuccess(result, bytes.size)
            } catch (error: Exception) {
                closeSocket()
                postError(
                    result,
                    "print_failed",
                    error.message ?: "Gagal mengirim data ke printer"
                )
            }
        }
    }

    private fun closeSocket() {
        try {
            socket?.close()
        } catch (_: Exception) {
        }
        socket = null
    }

    private fun postSuccess(result: MethodChannel.Result, value: Any? = true) {
        handler.post { result.success(value) }
    }

    private fun postError(result: MethodChannel.Result, code: String, message: String) {
        handler.post { result.error(code, message, null) }
    }
}
