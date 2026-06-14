import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:slyce/core/theme/app_theme.dart';

class RulerPicker extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final double step;
  final int decimalPlaces;
  final ValueChanged<double> onChanged;

  const RulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    this.step = 0.1,
    this.decimalPlaces = 1,
    required this.onChanged,
  });

  @override
  State<RulerPicker> createState() => _RulerPickerState();
}

class _RulerPickerState extends State<RulerPicker> {
  late ScrollController _scrollController;
  final double _itemWidth = 10.0;

  @override
  void initState() {
    super.initState();
    final initialOffset = ((widget.value - widget.min) / widget.step) * _itemWidth;
    _scrollController = ScrollController(initialScrollOffset: initialOffset.clamp(0, double.infinity));
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    final steps = (_scrollController.offset / _itemWidth).round();
    final newValue = (widget.min + steps * widget.step).clamp(widget.min, widget.max);
    final rounded = double.parse(newValue.toStringAsFixed(widget.decimalPlaces));
    if ((rounded - widget.value).abs() >= widget.step / 2) {
      HapticFeedback.selectionClick();
      widget.onChanged(rounded);
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalSteps = ((widget.max - widget.min) / widget.step).round();

    return SizedBox(
      height: 80,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Center indicator
          Center(
            child: Container(
              width: 2,
              height: 64,
              decoration: BoxDecoration(
                color: kPrimaryGreen,
                borderRadius: BorderRadius.circular(1),
              ),
            ),
          ),
          // Ruler
          NotificationListener<ScrollNotification>(
            onNotification: (n) {
              if (n is ScrollEndNotification) {
                // Snap to nearest step
                final steps = (_scrollController.offset / _itemWidth).round();
                _scrollController.animateTo(
                  steps * _itemWidth,
                  duration: const Duration(milliseconds: 100),
                  curve: Curves.easeOut,
                );
              }
              return false;
            },
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.symmetric(
                horizontal: MediaQuery.of(context).size.width / 2,
              ),
              itemCount: totalSteps + 1,
              itemBuilder: (context, index) {
                final isMajor = index % 10 == 0;
                final isMid = index % 5 == 0;
                return SizedBox(
                  width: _itemWidth,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 1.5,
                        height: isMajor ? 40 : (isMid ? 28 : 18),
                        color: isMajor
                            ? kDarkColor.withValues(alpha: 0.5)
                            : kGreyColor.withValues(alpha: 0.4),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


