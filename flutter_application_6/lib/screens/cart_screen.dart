// @dart=2.17

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../models/cart_item.dart';
import '../widgets/cart_widget.dart';
import '../widgets/glassmorphic_button.dart';
import '../services/restaurant_service.dart';
import './OrdersScreen.dart';
import '../utils/orderarugument.dart';

class CartScreen extends StatefulWidget {
  static const routeName = '/cart';
  final String? existingOrderId;

  const CartScreen({Key? key, this.existingOrderId}) : super(key: key);

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  bool _isLoading = false;

  void _proceedToCheckout(BuildContext context, CartProvider cart) async {
    try {
      setState(() => _isLoading = true);
      
      // Get restaurant data
      final restaurantId = cart.restaurantId;
      if (restaurantId == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: No restaurant found in cart'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final restaurantService = Provider.of<RestaurantService>(context, listen: false);
      final restaurant = await restaurantService.getRestaurantById(restaurantId);
      
      if (restaurant == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Restaurant not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      if (!mounted) return;

      // Check if we're editing an existing order
      if (widget.existingOrderId != null) {
        final cartItems = cart.items.values.toList();
        if (cartItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Invalid order data'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        Navigator.pushNamed(
          context,
          OrdersScreen.routeName,
          arguments: OrdersScreenArguments(
            totalPrice: cart.totalAmount,
            cartItems: cartItems,
            restaurant: restaurant,
            orderId: widget.existingOrderId,
          ),
        ).then((_) {
          Provider.of<CartProvider>(context, listen: false).clear();
        });
      } else {
        // Proceed without order ID
        final cartItems = cart.items.values.toList();
        if (cartItems.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error: Invalid cart data'),
              backgroundColor: Colors.red,
            ),
          );
          return;
        }
        Navigator.pushNamed(
          context,
          OrdersScreen.routeName,
          arguments: OrdersScreenArguments(
            totalPrice: cart.totalAmount,
            cartItems: cartItems,
            restaurant: restaurant,
          ),
        ).then((_) {
          Provider.of<CartProvider>(context, listen: false).clear();
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              cart.isEditingOrder ? 'Editing Order' : 'Your Cart',
              style: const TextStyle(fontSize: 20),
            ),
            backgroundColor: Colors.transparent,
            elevation: 0,
            actions: [
              if (cart.isEditingOrder)
                TextButton.icon(
                  onPressed: () {
                    cart.finishEditingOrder();
                    Navigator.pop(context);
                  },
                  icon: const Icon(Icons.close),
                  label: const Text('Cancel Edit'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: () {
                  Provider.of<CartProvider>(context, listen: false).clear();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Cart cleared')),
                  );
                },
              ),
            ],
          ),
          body: cart.isLoading || _isLoading
              ? const Center(child: CircularProgressIndicator())
              : cart.items.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.shopping_cart, size: 200),
                          const SizedBox(height: 20),
                          Text(
                            'Your cart is empty',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Add some delicious items to your cart',
                            style:
                                Theme.of(context).textTheme.bodyLarge?.copyWith(
                                      color: Colors.grey,
                                    ),
                          ),
                        ],
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: cart.items.length,
                            itemBuilder: (ctx, i) {
                              final item = cart.items.values.toList()[i];
                              return CartWidget(
                                item: item,
                                onRemove: () => cart.removeItem(item.id),
                                onDecrement: () =>
                                    cart.decrementQuantity(item.id),
                                onIncrement: () =>
                                    cart.incrementQuantity(item.id),
                              );
                            },
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Theme.of(context).cardColor,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                offset: const Offset(0, -4),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: SafeArea(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Total:',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge,
                                    ),
                                    Text(
                                      '\$${cart.totalAmount.toStringAsFixed(2)}',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge
                                          ?.copyWith(
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: GlassmorphicButton(
                                    onPressed: () {
                                      if (cart.items.isEmpty) {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(
                                          const SnackBar(
                                            content: Text('Your cart is empty'),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                        return;
                                      }

                                      _proceedToCheckout(context, cart);
                                    },
                                    child: Text(
                                      'Checkout (\$${cart.totalAmount.toStringAsFixed(2)})',
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
        );
      },
    );
  }
}
