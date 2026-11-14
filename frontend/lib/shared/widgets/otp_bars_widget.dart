import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_colors.dart';

/// Segmented 6-Digit OTP Box / Bar widget with high-visibility cursor and auto-focus for Driver App
class DriverOtpBarsWidget extends StatefulWidget {
  final int length;
  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;
  final FocusNode? focusNode;
  final bool autoFocus;
  final Color activeBorderColor;
  final Color inactiveBorderColor;
  final Color filledColor;

  const DriverOtpBarsWidget({
    super.key,
    this.length = 6,
    required this.controller,
    this.onCompleted,
    this.onChanged,
    this.focusNode,
    this.autoFocus = true,
    this.activeBorderColor = AppColors.ambulanceTeal,
    this.inactiveBorderColor = AppColors.borderDark,
    this.filledColor = AppColors.cardDark,
  });

  @override
  State<DriverOtpBarsWidget> createState() => _DriverOtpBarsWidgetState();
}

class _DriverOtpBarsWidgetState extends State<DriverOtpBarsWidget> {
  late final FocusNode _internalFocusNode;
  String _lastText = '';

  FocusNode get _effectiveFocusNode => widget.focusNode ?? _internalFocusNode;

  @override
  void initState() {
    super.initState();
    _internalFocusNode = FocusNode();
    _lastText = widget.controller.text;
    widget.controller.addListener(_handleTextChange);
    _effectiveFocusNode.addListener(_handleFocusChange);

    if (widget.autoFocus) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _openKeyboard();
        }
      });
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleTextChange);
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _internalFocusNode.dispose();
    super.dispose();
  }

  void _openKeyboard() {
    _effectiveFocusNode.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {});
    }
  }

  void _handleTextChange() {
    if (!mounted) return;
    final current = widget.controller.text;
    if (current == _lastText) return;

    final prev = _lastText;
    _lastText = current;
    setState(() {});
    widget.onChanged?.call(current);
    if (current.length == widget.length && prev.length < widget.length) {
      widget.onCompleted?.call(current);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text;

    return SizedBox(
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 6 Individual Segmented OTP Digit Bars / Boxes
          IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(widget.length, (index) {
                final isFocused = _effectiveFocusNode.hasFocus &&
                    (text.length == index || (text.length == widget.length && index == widget.length - 1));
                final hasChar = index < text.length;
                final char = hasChar ? text[index] : '';

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 46,
                  height: 56,
                  decoration: BoxDecoration(
                    color: widget.filledColor,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isFocused
                          ? widget.activeBorderColor
                          : (hasChar
                              ? widget.activeBorderColor.withValues(alpha: 0.6)
                              : widget.inactiveBorderColor),
                      width: isFocused ? 2.2 : 1.4,
                    ),
                    boxShadow: isFocused
                        ? [
                            BoxShadow(
                              color: widget.activeBorderColor.withValues(alpha: 0.28),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : null,
                  ),
                  child: Center(
                    child: hasChar
                        ? Text(
                            char,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          )
                        : (isFocused
                            ? Container(
                                width: 2,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: widget.activeBorderColor,
                                  borderRadius: BorderRadius.circular(1),
                                ),
                              )
                            : Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: widget.inactiveBorderColor.withValues(alpha: 0.7),
                                  shape: BoxShape.circle,
                                ),
                              )),
                  ),
                );
              }),
            ),
          ),

          // Full-width interactive transparent TextField covering all 6 boxes
          // so tapping anywhere reliably opens the numeric dial pad on Android/MIUI & Web.
          Positioned.fill(
            child: TextField(
              controller: widget.controller,
              focusNode: _effectiveFocusNode,
              autofocus: widget.autoFocus,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.oneTimeCode],
              showCursor: false,
              cursorColor: Colors.transparent,
              enableInteractiveSelection: false,
              style: const TextStyle(color: Colors.transparent, fontSize: 22),
              maxLength: widget.length,
              onTap: _openKeyboard,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
              decoration: const InputDecoration(
                counterText: '',
                filled: false,
                fillColor: Colors.transparent,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

