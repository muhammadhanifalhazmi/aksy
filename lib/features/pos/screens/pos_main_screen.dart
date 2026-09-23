import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/data/app_store.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/widgets/barcode_scanner_screen.dart';
import '../../cash_flow/screens/cash_flow_screen.dart';
import '../../debt/screens/debt_screen.dart';
import '../../inventory/screens/inventory_screen.dart';
import '../../reports/screens/reports_screen.dart';
import '../../shift/screens/shift_screen.dart';
import '../models/cart_item.dart';
import '../models/product.dart';
import '../providers/cart_provider.dart';
import 'receipt_preview_dialog.dart';

class POSMainScreen extends StatefulWidget {
  const POSMainScreen({super.key});

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
      drawer: _BuildDrawer(),
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
            onPressed: () => _openCartDrawer(context, cart),
            tooltip: 'Keranjang',
            icon: Badge(
              isLabelVisible: cart.itemCount > 0,
              label: Text('${cart.itemCount}'),
              child: const Icon(Icons.shopping_cart_outlined),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const InventoryScreen()),
            ),
            tooltip: 'Inventori',
            icon: const Icon(Icons.inventory_2_outlined),
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
              ? _EmptyProducts(
                  onAddPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const InventoryScreen(),
                    ),
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

  void _openCartDrawer(BuildContext context, CartProvider cart) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CartSheet(cart: cart),
    );
  }
}

class _BuildDrawer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final store = AppScope.of(context);
    return NavigationDrawer(
      onDestinationSelected: (index) {
        final navigator = Navigator.of(context);
        navigator.pop();
        switch (index) {
          case 0:
            break;
          case 1:
            navigator.push(
              MaterialPageRoute(builder: (_) => const InventoryScreen()),
            );
          case 2:
            navigator.push(
              MaterialPageRoute(builder: (_) => const CashFlowScreen()),
            );
          case 3:
            navigator.push(
              MaterialPageRoute(builder: (_) => const DebtScreen()),
            );
          case 4:
            navigator.push(
              MaterialPageRoute(builder: (_) => const ShiftScreen()),
            );
          case 5:
            navigator.push(
              MaterialPageRoute(builder: (_) => const ReportsScreen()),
            );
        }
      },
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Image(
                    image: AssetImage('assets/images/icon.png'),
                    width: 40,
                    height: 40,
                  ),
                  const SizedBox(width: 12),
                    Flexible(
                      child: Text(
                        'Aplikasi Kasir Easy',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                store.activeShift == null
                    ? 'Shift belum dibuka'
                    : 'Shift ${store.activeShift!.id} aktif',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: store.activeShift == null
                      ? theme.colorScheme.outline
                      : theme.colorScheme.primary,
                ),
              ),
            ],
          ),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.point_of_sale),
          label: Text('POS'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.inventory_2_outlined),
          label: Text('Inventori'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.account_balance_wallet_outlined),
          label: Text('Kas Masuk / Keluar'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: Text('Hutang & Piutang'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.history),
          label: Text('Shift Kasir'),
        ),
        const NavigationDrawerDestination(
          icon: Icon(Icons.summarize_outlined),
          label: Text('Laporan'),
        ),
      ],
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

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts({required this.onAddPressed});

  final VoidCallback onAddPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: theme.colorScheme.primary.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'Belum ada produk',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tambahkan produk terlebih dahulu lewat menu Inventori '
              'agar bisa dijual atau dipindai.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAddPressed,
              icon: const Icon(Icons.add),
              label: const Text('Tambah Produk'),
            ),
          ],
        ),
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
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
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
  const _CartSheet({required this.cart});

  final CartProvider cart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
  final screenContext = context;
  final cashController = TextEditingController(text: '${cart.subtotal}');
  final discountController = TextEditingController();
  final focusNode = FocusNode();
  var cash = cart.subtotal;
  var discount = 0;

  Future<void> close() async {
    focusNode.dispose();
    cashController.dispose();
    discountController.dispose();
    Navigator.of(screenContext).pop();
  }

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final theme = Theme.of(dialogContext);
      final total = cart.subtotal - discount;
      final difference = cash - total;
      final isEnough = difference >= 0 && cash > 0;
      return StatefulBuilder(
        builder: (context, setDialogState) {
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
                      '${discount > 0 ? ' (diskon ${CurrencyFormatter.formatIDR(discount)})' : ''}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: cashController,
                      focusNode: focusNode,
                      autofocus: true,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => setDialogState(
                        () => cash = int.tryParse(value) ?? 0,
                      ),
                      decoration: InputDecoration(
                        labelText: 'Uang diterima',
                        prefixText: 'Rp ',
                        border: const OutlineInputBorder(),
                        helperText: 'Tekan angka di bawah untuk isi cepat',
                        helperMaxLines: 1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: discountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (value) => setDialogState(
                        () => discount = int.tryParse(value) ?? 0,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Diskon (Rp)',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ActionChip(
                          label: const Text('Uang Pas'),
                          onPressed: () {
                            cash = total;
                            cashController.text = '$cash';
                            setDialogState(() {});
                          },
                        ),
                        for (final amount in const [20000, 50000, 100000])
                          ActionChip(
                            label: Text(CurrencyFormatter.formatIDR(amount)),
                            onPressed: () {
                              cash = amount;
                              cashController.text = '$amount';
                              setDialogState(() {});
                            },
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
                            onPressed: close,
                            child: const Text('Batal'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 2,
                          child: FilledButton(
                            onPressed: isEnough && cash >= total
                                ? () async {
                                    final order = cart.submitOrder(
                                      cash,
                                      store,
                                      discount: discount,
                                    );
                                    await close();
                                    if (!screenContext.mounted) return;
                                    if (order.change > 0) {
                                      ScaffoldMessenger.of(screenContext)
                                          .showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Kembalian ${CurrencyFormatter.formatIDR(order.change)}',
                                          ),
                                        ),
                                      );
                                    }
                                    if (screenContext.mounted) {
                                      await showReceiptPreview(
                                        screenContext,
                                        order: order,
                                        store: store,
                                      );
                                    }
                                  }
                                : null,
                            child: const Text('Bayar'),
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
        },
      );
    },
  );
}