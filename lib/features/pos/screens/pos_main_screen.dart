import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/app_store.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/app_navigation_drawer.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../../core/widgets/empty_state.dart';
import '../../printer/services/print_receipt_action.dart';
import '../models/cart_item.dart';
import '../models/order.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import 'receipt_preview_dialog.dart';

class POSMainScreen extends StatefulWidget {
  const POSMainScreen({
    super.key,
    required this.selectedDestination,
    required this.onDestinationSelected,
  });

  final AppDestination selectedDestination;
  final ValueChanged<AppDestination> onDestinationSelected;

  @override
  State<POSMainScreen> createState() => _POSMainScreenState();
}

class _POSMainScreenState extends State<POSMainScreen> {
  String _selectedCategory = 'Semua';
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final cart = CartScope.of(context);
    return Scaffold(
      drawer: AppNavigationDrawer(
        selectedDestination: widget.selectedDestination,
        onDestinationSelected: widget.onDestinationSelected,
      ),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Image(
              image: AssetImage('assets/images/icon.png'),
              width: 28,
              height: 28,
            ),
            const SizedBox(width: 10),
            Flexible(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'Aplikasi Kasir Easy',
                  maxLines: 1,
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () => _openCartDrawer(context),
            tooltip: 'Keranjang',
            icon: Badge(
              isLabelVisible: cart.itemCount > 0,
              label: Text('${cart.itemCount}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          IconButton(
            onPressed: () =>
                widget.onDestinationSelected(AppDestination.inventory),
            tooltip: 'Inventori',
            icon: const Icon(Icons.inventory_2_outlined),
          ),
          IconButton(
            onPressed: () => widget.onDestinationSelected(AppDestination.guide),
            tooltip: 'Panduan',
            icon: const Icon(Icons.help_outline),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final products = _filteredProducts();
          final isWide = constraints.maxWidth >= 820;
          if (isWide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _buildProductArea(products)),
                _CartPanel(width: 380),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildProductArea(products)),
              _BottomCartBar(cart: cart),
            ],
          );
        },
      ),
    );
  }

  List<Product> _filteredProducts() {
    final store = AppScope.of(context);
    final query = _query.trim().toLowerCase();
    final products = store.products.where((p) {
      if (query.isNotEmpty) {
        final matchesName = p.name.toLowerCase().contains(query);
        final matchesBarcode = (p.barcode ?? '').contains(query);
        if (!matchesName && !matchesBarcode) return false;
      }
      if (_selectedCategory != 'Semua' && p.category != _selectedCategory) {
        return false;
      }
      return true;
    }).toList();
    return products;
  }

  Widget _buildProductArea(List<Product> products) {
    final store = AppScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            textInputAction: TextInputAction.done,
            onSubmitted: (value) => _addByBarcode(value),
            decoration: InputDecoration(
              hintText: 'Cari produk atau barcode...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                onPressed: _openBarcodeScanner,
                tooltip: 'Scan barcode',
                icon: const Icon(Icons.qr_code_scanner),
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        _CategoryFilter(
          selected: _selectedCategory,
          onSelected: (category) =>
              setState(() => _selectedCategory = category),
          categories: _categories(store),
        ),
        Expanded(
          child: products.isEmpty
              ? EmptyState(
                  icon: Icons.inventory_2_outlined,
                  iconSize: 64,
                  title: 'Belum ada produk',
                  subtitle: 'Tambahkan produk terlebih dahulu lewat menu '
                      'Inventori agar bisa dijual atau dipindai.',
                  action: FilledButton.icon(
                    onPressed: () => widget.onDestinationSelected(
                      AppDestination.inventory,
                    ),
                    icon: const Icon(Icons.add),
                    label: const Text('Tambah Produk'),
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 150,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.72,
                  ),
                  itemCount: products.length,
                  itemBuilder: (context, index) {
                    return _ProductCard(product: products[index]);
                  },
                ),
        ),
      ],
    );
  }

  List<String> _categories(AppStore store) {
    return ['Semua', ...store.categories];
  }

  Future<void> _openBarcodeScanner() async {
    final store = AppScope.of(context);
    final cart = CartScope.of(context);
    final product = await showBarcodeScanner(
      context,
      products: store.products,
    );
    if (product == null || !mounted) return;
    _addToCart(cart, product);
  }

  void _addByBarcode(String query) {
    final store = AppScope.of(context);
    final cart = CartScope.of(context);
    final product = store.productByBarcode(query);
    if (product != null) {
      _addToCart(cart, product);
    }
  }

  void _addToCart(CartProvider cart, Product product) {
    if (product.stock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${product.name} stok habis')),
      );
      return;
    }
    cart.addItem(product, availableStock: product.stock);
    if (cart.quantityOf(product.id) >= product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stok ${product.name} mencapai batas maksimal')),
      );
    }
  }

  void _openCartDrawer(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _CartSheet(),
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.selected,
    required this.onSelected,
    required this.categories,
  });

  final String selected;
  final ValueChanged<String> onSelected;
  final List<String> categories;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selected;
          return ChoiceChip(
            label: Text(category),
            selected: isSelected,
            showCheckmark: false,
            onSelected: (_) => onSelected(category),
            selectedColor: Theme.of(context).colorScheme.primary,
            labelStyle: TextStyle(
              color: isSelected ? Colors.white : null,
              fontWeight: FontWeight.w600,
            ),
          );
        },
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product});

  final Product product;

  Widget _thumbPlaceholder(ThemeData theme) {
    return Container(
      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Icon(product.icon, size: 32, color: theme.colorScheme.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = CartScope.of(context);
    final qty = cart.quantityOf(product.id);
    final outOfStock = product.stock <= 0;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(AppTheme.radius),
        onTap: outOfStock ? null : () => _registerTap(context, cart),
        child: Opacity(
          opacity: outOfStock ? 0.55 : 1,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: constraints.maxWidth,
                  child: Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                height: 52,
                                width: double.infinity,
                                child: product.imagePath != null
                                    ? Image.file(
                                        File(product.imagePath!),
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _thumbPlaceholder(theme),
                                      )
                                    : _thumbPlaceholder(theme),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              CurrencyFormatter.formatIDR(product.price),
                              maxLines: 1,
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (product.hasWholesaleTier) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Grosir dari ${product.minWholesaleQty} pcs',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              outOfStock
                                  ? 'Stok habis'
                                  : 'Stok ${product.stock}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: outOfStock
                                    ? theme.colorScheme.error
                                    : theme.colorScheme.outline,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (qty > 0)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$qty',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _registerTap(BuildContext context, CartProvider cart) {
    if (product.stock <= 0) return;
    cart.addItem(product, availableStock: product.stock);
    if (cart.quantityOf(product.id) >= product.stock) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Stok ${product.name} mencapai batas maksimal')),
      );
    }
  }
}

class _CartPanel extends StatelessWidget {
  const _CartPanel({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = CartScope.of(context);
    final store = AppScope.of(context);
    return Material(
      color: theme.colorScheme.surfaceContainerLow,
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                children: [
                  Text(
                    'Pesanan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (!cart.isEmpty)
                    Text(
                      '${cart.itemCount} item',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: cart.isEmpty
                  ? const _EmptyCart()
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) =>
                          _CartItemTile(item: cart.items[index]),
                    ),
            ),
            _CheckoutFooter(cart: cart, store: store),
          ],
        ),
      ),
    );
  }
}

class _CartSheet extends StatelessWidget {
  const _CartSheet();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = CartScope.of(context);
    final store = AppScope.of(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.7,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Row(
                children: [
                  Text(
                    'Pesanan',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  if (!cart.isEmpty)
                    Text(
                      '${cart.itemCount} item',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                ],
              ),
            ),
            Expanded(
              child: cart.isEmpty
                  ? const _EmptyCart()
                  : ListView.separated(
                      itemCount: cart.items.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 4),
                      itemBuilder: (context, index) =>
                          _CartItemTile(item: cart.items[index]),
                    ),
            ),
            _CheckoutFooter(cart: cart, store: store),
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  const _CartItemTile({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = CartScope.of(context);
    final store = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        item.product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (item.isWholesale) ...[
                      const SizedBox(width: 6),
                      _WholesaleTag(),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '${CurrencyFormatter.formatIDR(item.unitPrice)} / pcs'
                  '${item.isWholesale ? ' (grosir)' : ''}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          _QtyStepper(
            item: item,
            availableStock: store.stockOf(item.product.id),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 96,
            child: Text(
              CurrencyFormatter.formatIDR(item.subtotal),
              textAlign: TextAlign.right,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          IconButton(
            onPressed: () => cart.removeItem(item.product.id),
            tooltip: 'Hapus',
            visualDensity: VisualDensity.compact,
            icon: Icon(
              Icons.delete_outline,
              size: 20,
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }
}

class _WholesaleTag extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        'grosir',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  const _QtyStepper({required this.item, required this.availableStock});

  final CartItem item;
  final int availableStock;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cart = CartScope.of(context);
    final atCap = item.quantity >= availableStock;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: Icons.remove,
          onTap: () => cart.decrement(item.product.id),
        ),
        SizedBox(
          width: 28,
          child: Text(
            '${item.quantity}',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        _StepButton(
          icon: Icons.add,
          onTap: atCap
              ? null
              : () => cart.increment(
                    item.product.id,
                    availableStock: availableStock,
                  ),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: Icon(
          icon,
          size: 18,
          color: onTap == null
              ? theme.colorScheme.outlineVariant
              : theme.colorScheme.primary,
        ),
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 44,
            color: theme.colorScheme.outlineVariant,
          ),
          const SizedBox(height: 8),
          Text(
            'Keranjang masih kosong',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

class _CheckoutFooter extends StatelessWidget {
  const _CheckoutFooter({required this.cart, required this.store});

  final CartProvider cart;
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text(
                'Subtotal',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              Text(
                CurrencyFormatter.formatIDR(cart.subtotal),
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Total',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              Text(
                CurrencyFormatter.formatIDR(cart.subtotal),
                style: theme.textTheme.titleLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: cart.isEmpty
                ? null
                : () => _showPaymentDialog(context, cart, store),
            icon: const Icon(Icons.payments_outlined),
            label: Text('Bayar ${CurrencyFormatter.formatIDR(cart.subtotal)}'),
          ),
        ],
      ),
    );
  }
}

class _BottomCartBar extends StatelessWidget {
  const _BottomCartBar({required this.cart});

  final CartProvider cart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (cart.isEmpty) return const SizedBox.shrink();
    return Material(
      color: theme.colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${cart.itemCount} item',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatIDR(cart.subtotal),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: () =>
                    _showPaymentDialog(context, cart, AppScope.of(context)),
                icon: const Icon(Icons.payments_outlined),
                label: const Text('Bayar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> _showPaymentDialog(
  BuildContext context,
  CartProvider cart,
  AppStore store,
) async {
  final order = await showDialog<Order>(
    context: context,
    builder: (_) => _PaymentDialog(cart: cart, store: store),
  );
  if (order == null || !context.mounted) return;

  if (order.change > 0) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Kembalian ${CurrencyFormatter.formatIDR(order.change)}'),
      ),
    );
  }
  if (!context.mounted) return;
  if (store.printer.autoPrint) {
    if (!store.printer.isConfigured) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cetak otomatis aktif tapi printer belum dipilih. '
            'Buka menu Printer Termal.',
          ),
        ),
      );
    } else {
      try {
        final outcome = await printReceipt(
          context: context,
          store: store,
          order: order,
        );
        if (!context.mounted) return;
        if (outcome.printed) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Struk dicetak ke ${store.printer.deviceName}',
              ),
            ),
          );
        } else if (outcome.status == PrintStatus.failed) {
          await showPrintFailureDialog(
            context,
            message: outcome.message,
            onRetry: () => printReceiptManually(
              context: context,
              store: store,
              order: order,
            ),
          );
        }
      } catch (error) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Gagal mencetak struk: $error')),
        );
      }
    }
  }
  if (context.mounted) {
    await showReceiptPreview(context, order: order, store: store);
  }
}

class _PaymentDialog extends StatefulWidget {
  const _PaymentDialog({required this.cart, required this.store});

  final CartProvider cart;
  final AppStore store;

  @override
  State<_PaymentDialog> createState() => _PaymentDialogState();
}

class _PaymentDialogState extends State<_PaymentDialog> {
  late final TextEditingController _cashController;
  late final TextEditingController _discountController;
  final FocusNode _focusNode = FocusNode();

  late int _cash;
  int _discount = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _cash = widget.cart.subtotal;
    _cashController = TextEditingController(text: '$_cash');
    _discountController = TextEditingController();
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _cashController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  int get _subtotal => widget.cart.subtotal;

  int get _maxDiscount => _subtotal;

  int get _total => _subtotal - _discount;

  int get _difference => _cash - _total;

  bool get _isEnough => _difference >= 0 && _cash > 0;

  void _setCash(int value) {
    setState(() {
      _cash = value;
      _cashController.text = '$value';
    });
  }

  Future<void> _pay() async {
    if (_busy) return;
    final store = widget.store;
    final missing = widget.cart.items
        .where((item) => store.productById(item.product.id) == null)
        .length;
    if (missing > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Ada $missing produk di keranjang yang sudah tidak tersedia. '
            'Muat ulang kasir sebelum membayar.',
          ),
        ),
      );
      return;
    }
    setState(() => _busy = true);
    final order = widget.cart.submitOrder(
      _cash,
      store,
      discount: _discount,
    );
    if (!mounted) return;
    Navigator.of(context).pop(order);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = _total;
    final difference = _difference;
    final isEnough = _isEnough;
    return SafeArea(
      child: Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Pembayaran',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Total tagihan ${CurrencyFormatter.formatIDR(total)}'
                  '${_discount > 0 ? ' (diskon ${CurrencyFormatter.formatIDR(_discount)})' : ''}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _cashController,
                  focusNode: _focusNode,
                  autofocus: !_busy,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) =>
                      setState(() => _cash = int.tryParse(value) ?? 0),
                  decoration: const InputDecoration(
                    labelText: 'Uang diterima',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                    helperText: 'Tekan angka di bawah untuk isi cepat',
                    helperMaxLines: 1,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _discountController,
                  enabled: !_busy,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  onChanged: (value) => setState(() {
                    final typed = int.tryParse(value) ?? 0;
                    _discount = typed > _maxDiscount ? _maxDiscount : typed;
                    if (typed > _maxDiscount) {
                      _discountController.text = '$_maxDiscount';
                      _discountController.selection =
                          TextSelection.collapsed(offset: '$_maxDiscount'.length);
                    }
                  }),
                  decoration: InputDecoration(
                    labelText: 'Diskon (Rp)',
                    prefixText: 'Rp ',
                    helperText: 'Maksimal ${CurrencyFormatter.formatIDR(_maxDiscount)}',
                    border: const OutlineInputBorder(),
                  ),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('Uang Pas'),
                      onPressed: _busy ? null : () => _setCash(total),
                    ),
                    for (final amount in const [20000, 50000, 100000])
                      ActionChip(
                        label: Text(CurrencyFormatter.formatIDR(amount)),
                        onPressed: _busy ? null : () => _setCash(amount),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEnough ? 'Kembalian' : 'Kurang',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      CurrencyFormatter.formatIDR(difference.abs()),
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: isEnough
                            ? theme.colorScheme.primary
                            : theme.colorScheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.of(context).pop(),
                        child: const Text('Batal'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        onPressed: (isEnough && !_busy) ? _pay : null,
                        child: Text(_busy ? 'Memproses...' : 'Bayar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}