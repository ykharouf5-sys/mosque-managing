import 'package:studentry/utils/app_locale.dart';
import 'package:studentry/store/presentation/store_ui.dart';
import 'package:studentry/store/data/store_models.dart';
import 'package:studentry/utils/variable_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:studentry/store/presentation/providers/store_providers.dart';
import 'package:studentry/store/presentation/delivery_location_map.dart';
import 'package:studentry/store/presentation/widgets/delivery_location_field.dart';
import 'package:studentry/store/presentation/widgets/order_submission_notice.dart';
import 'package:studentry/store/presentation/widgets/cod_payment_option.dart';

const List<String> _governorates = [
  'دمشق',
  'ريف دمشق',
  'حلب',
  'حمص',
  'اللاذقية',
  'حماة',
  'طرطوس',
  'إدلب',
  'دير الزور',
  'الحسكة',
  'الرقة',
  'درعا',
  'السويداء',
  'القنيطرة',
];

class OrderConfirmationScreen extends ConsumerStatefulWidget {
  const OrderConfirmationScreen({super.key});

  @override
  ConsumerState<OrderConfirmationScreen> createState() =>
      _OrderConfirmationScreenState();
}

class _OrderConfirmationScreenState
    extends ConsumerState<OrderConfirmationScreen> {
  final _phoneC = TextEditingController();
  final _regionC = TextEditingController();
  final _detailsC = TextEditingController();
  final _couponC = TextEditingController();
  String? _selectedGovernorate;
  final String _paymentMethod = 'cash_on_delivery';
  bool _isLoading = false;
  bool _couponLoading = false;
  String? _couponError;
  DeliveryPoint? _deliveryPoint;
  bool _showLocationMap = false;
  static final _locationLine = RegExp(
    r'(?:\n)?الموقع على الخريطة: https://maps\.google\.com/\?q=[^\n]*',
  );

  void _setDeliveryPoint(DeliveryPoint? point) {
    final writtenAddress = _detailsC.text.replaceAll(_locationLine, '').trim();
    final locationText = point == null
        ? ''
        : 'الموقع على الخريطة: ${point.mapUrl}';
    _detailsC.text = [
      if (writtenAddress.isNotEmpty) writtenAddress,
      if (locationText.isNotEmpty) locationText,
    ].join('\n');
    _detailsC.selection = TextSelection.collapsed(
      offset: _detailsC.text.length,
    );
    setState(() {
      _deliveryPoint = point;
      _showLocationMap = false;
    });
  }

  @override
  void dispose() {
    _phoneC.dispose();
    _regionC.dispose();
    _detailsC.dispose();
    _couponC.dispose();
    super.dispose();
  }

  void _removeCoupon() {
    ref.read(cartProvider.notifier).removeCoupon();
    setState(() => _couponError = null);
  }

  Future<void> _confirmOrder() async {
    final phone = _phoneC.text.trim();
    if (phone.isEmpty) {
      _showError('يرجى إدخال رقم الهاتف');
      return;
    }
    if (_selectedGovernorate == null) {
      _showError('يرجى اختيار المحافظة');
      return;
    }
    final region = _regionC.text.trim();
    if (region.isEmpty) {
      _showError('يرجى إدخال اسم المنطقة');
      return;
    }
    final details = _detailsC.text.trim();
    if (details.isEmpty) {
      _showError('يرجى إدخال تفاصيل العنوان');
      return;
    }

    final fullAddress = '$_selectedGovernorate - $region - $details';

    setState(() => _isLoading = true);
    try {
      final order = await ref
          .read(cartProvider.notifier)
          .placeOrder(
            shippingAddress: fullAddress,
            notes: null,
            paymentMethod: _paymentMethod,
            phone: phone,
            governorate: _selectedGovernorate,
            region: region,
            locationLatitude: _deliveryPoint?.latitude,
            locationLongitude: _deliveryPoint?.longitude,
          );
      if (!mounted) return;
      ref.read(ordersProvider.notifier).addOrder(order);
      ref.read(cartProvider.notifier).clearCart();
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/my-orders',
        (route) => route.settings.name == '/cart' ? false : true,
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: OrderSubmissionNotice(awaitingSync: order.awaitingSync),
          backgroundColor: order.awaitingSync
              ? AppColors.primary
              : AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showError('فشل إرسال الطلب: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    Localizations.localeOf(context);
    final cart = ref.watch(cartProvider);
    final cartItems = cart.items;
    final discountedTotal = cart.discountedTotal;
    final appliedCoupon = cart.appliedCoupon;

    final deliveryTotal = cart.deliveryTotal;
    final grandTotal = cart.grandTotal;

    return Directionality(
      textDirection: AppLocale.language == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(storeUi('تأكيد الطلب')),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: AppColors.textDark),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: SingleChildScrollView(
          padding: EdgeInsets.all(16.w),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionTitle('منتجات الطلب'),
              SizedBox(height: 8.h),
              ...cartItems.map(_buildCartItem),
              SizedBox(height: 8.h),
              _buildDivider(),
              _buildPriceRow(
                'المجموع الفرعي',
                '${discountedTotal.toStringAsFixed(0)} SYP',
              ),
              _buildPriceRow(
                'تكلفة التوصيل',
                '${deliveryTotal.toStringAsFixed(0)} SYP',
              ),
              _buildPriceRow(
                'المجموع النهائي',
                '${grandTotal.toStringAsFixed(0)} SYP',
                bold: true,
              ),
              SizedBox(height: 20.h),
              _buildSectionTitle('معلومات التوصيل'),
              SizedBox(height: 8.h),
              _buildPhoneField(),
              SizedBox(height: 12.h),
              _buildGovernorateDropdown(),
              SizedBox(height: 12.h),
              _buildRegionField(),
              SizedBox(height: 12.h),
              _buildDetailsField(),
              if (_showLocationMap) ...[
                SizedBox(height: 8.h),
                DeliveryLocationMap(
                  initialPoint: _deliveryPoint,
                  onConfirm: _setDeliveryPoint,
                ),
              ],
              SizedBox(height: 20.h),
              _buildSectionTitle('كود الخصم'),
              SizedBox(height: 8.h),
              _buildCouponField(appliedCoupon),
              SizedBox(height: 20.h),
              _buildSectionTitle('طريقة الدفع'),
              SizedBox(height: 8.h),
              _buildPaymentSelector(),
              SizedBox(height: 24.h),
              _buildConfirmButton(),
              SizedBox(height: 16.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: AppColors.authTextDark,
        fontSize: 16.sp,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _buildCartItem(CartItem item) {
    return Container(
      margin: EdgeInsets.only(bottom: 8.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textDark,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  AppLocale.text(
                    'الكمية: ${item.quantity}',
                    'Quantity: ${item.quantity}',
                  ),
                  style: TextStyle(fontSize: 12.sp, color: AppColors.authGrey),
                ),
              ],
            ),
          ),
          Text(
            storeUi(
              '${(item.product.price * item.quantity).toStringAsFixed(0)} SYP',
            ),
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      color: AppColors.divider,
      margin: EdgeInsets.symmetric(vertical: 8.h),
    );
  }

  Widget _buildPriceRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4.h),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: bold ? 15.sp : 13.sp,
              fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
              color: AppColors.authGrey,
            ),
          ),
          Spacer(),
          Text(
            value,
            style: TextStyle(
              fontSize: bold ? 17.sp : 14.sp,
              fontWeight: FontWeight.w700,
              color: bold ? AppColors.authTextDark : AppColors.authTextDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneC,
      keyboardType: TextInputType.phone,
      textDirection: TextDirection.ltr,
      decoration: InputDecoration(
        labelText: storeUi('رقم الهاتف'),
        hintText: storeUi('أعد إدخال رقم الهاتف للتأكيد'),
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: Icon(
          Icons.phone_outlined,
          color: AppColors.primary,
          size: 20.sp,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      ),
    );
  }

  Widget _buildGovernorateDropdown() {
    return DropdownButtonFormField<String>(
      initialValue: _selectedGovernorate,
      decoration: InputDecoration(
        labelText: storeUi('المحافظة'),
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: Icon(
          Icons.location_city_outlined,
          color: AppColors.primary,
          size: 20.sp,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      ),
      items: _governorates
          .map((g) => DropdownMenuItem(value: g, child: Text(g)))
          .toList(),
      onChanged: (v) => setState(() => _selectedGovernorate = v),
    );
  }

  Widget _buildRegionField() {
    return TextField(
      controller: _regionC,
      textDirection: AppLocale.language == 'ar'
          ? TextDirection.rtl
          : TextDirection.ltr,
      decoration: InputDecoration(
        labelText: storeUi('المنطقة'),
        hintText: storeUi('اسم المنطقة أو الحي'),
        filled: true,
        fillColor: AppColors.surface,
        prefixIcon: Icon(
          Icons.map_outlined,
          color: AppColors.primary,
          size: 20.sp,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
      ),
    );
  }

  Widget _buildDetailsField() {
    return DeliveryLocationField(
      controller: _detailsC,
      latitude: _deliveryPoint?.latitude,
      longitude: _deliveryPoint?.longitude,
      mapExpanded: _showLocationMap,
      onChooseLocation: () =>
          setState(() => _showLocationMap = !_showLocationMap),
      onClearLocation: () => _setDeliveryPoint(null),
    );
  }

  Widget _buildCouponField(Coupon? appliedCoupon) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _couponC,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                  hintText: storeUi('أدخل كود الخصم'),
                  hintTextDirection: TextDirection.rtl,
                  filled: true,
                  fillColor: AppColors.surface,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12.w,
                    vertical: 14.h,
                  ),
                ),
              ),
            ),
            SizedBox(width: 8.w),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.onPrimary,
                padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 14.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: _couponLoading
                  ? null
                  : () async {
                      final code = _couponC.text.trim().toUpperCase();
                      if (code.isEmpty) return;
                      setState(() => _couponLoading = true);
                      final error = await ref
                          .read(cartProvider.notifier)
                          .applyCoupon(code);
                      if (!mounted) return;
                      setState(() {
                        _couponLoading = false;
                        _couponError = error;
                      });
                    },
              child: _couponLoading
                  ? SizedBox(
                      width: 16.w,
                      height: 16.h,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(storeUi('تطبيق')),
            ),
          ],
        ),
        if (_couponError != null)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Text(
              _couponError!,
              style: TextStyle(color: Colors.red, fontSize: 12.sp),
            ),
          ),
        if (appliedCoupon != null)
          Padding(
            padding: EdgeInsets.only(top: 6.h),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.success, size: 16.sp),
                SizedBox(width: 4.w),
                Text(
                  AppLocale.text(
                    'كود ${appliedCoupon.code} مطبق',
                    'Coupon ${appliedCoupon.code} applied',
                  ),
                  style: TextStyle(color: AppColors.success, fontSize: 12.sp),
                ),
                SizedBox(width: 8.w),
                GestureDetector(
                  onTap: _removeCoupon,
                  child: Icon(
                    Icons.close,
                    color: AppColors.authGrey,
                    size: 16.sp,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildPaymentSelector() => CodPaymentOption();

  Widget _buildConfirmButton() {
    return SizedBox(
      width: double.infinity,
      height: 52.h,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          shadowColor: AppColors.primary.withValues(alpha: 0.25),
        ),
        onPressed: _isLoading ? null : _confirmOrder,
        child: _isLoading
            ? SizedBox(
                width: 22.w,
                height: 22.h,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 18.sp),
                  SizedBox(width: 8.w),
                  Text(
                    storeUi('تأكيد الطلب'),
                    style: TextStyle(
                      fontSize: 15.sp,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
