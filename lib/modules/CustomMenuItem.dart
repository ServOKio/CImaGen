import 'package:flutter/material.dart';
import 'package:flutter_context_menu/flutter_context_menu.dart';

final class CustomMenuItem<T> extends ContextMenuItem<T> {
  final String label;
  final IconData? icon;
  final Color? iconColor;
  final BoxConstraints? constraints;

  const CustomMenuItem({
    required this.label,
    this.icon,
    this.iconColor,
    super.value,
    super.onSelected,
    this.constraints,
  });

  const CustomMenuItem.submenu({
    required this.label,
    required List<ContextMenuEntry> items,
    this.icon,
    this.iconColor,
    super.onSelected,
    this.constraints,
  }) : super.submenu(items: items);

  @override
  Widget builder(BuildContext context, ContextMenuState menuState, [FocusNode? focusNode]) {
    bool isFocused = menuState.focusedEntry == this;

    final background = Theme.of(context).colorScheme.surface;
    final normalTextColor = Color.alphaBlend(
        Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
        background,
    );
    final focusedTextColor = Theme.of(context).colorScheme.onSurface;
    final foregroundColor = isFocused ? focusedTextColor : normalTextColor;
    final textStyle = TextStyle(color: foregroundColor, height: 1.0);

    // ~~~~~~~~~~ //

    return ConstrainedBox(
      constraints: constraints ?? const BoxConstraints.expand(height: 32.0),
      child: Material(
        color: isFocused ? iconColor?.withAlpha(20) ?? Theme.of(context).focusColor.withAlpha(20) : background,
        borderRadius: BorderRadius.circular(4.0),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => handleItemSelection(context),
          canRequestFocus: false,
          child: DefaultTextStyle(
            style: textStyle,
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 32.0,
                  child: Icon(
                    icon,
                    size: 16.0,
                    color: iconColor ?? foregroundColor,
                  ),
                ),
                const SizedBox(width: 4.0),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8.0),
                SizedBox.square(
                  dimension: 32.0,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Icon(
                      isSubmenuItem ? Icons.arrow_right : null,
                      size: 16.0,
                      color: iconColor ?? foregroundColor,
                    ),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  String get debugLabel => "[${hashCode.toString().substring(0, 5)}] $label";
}
