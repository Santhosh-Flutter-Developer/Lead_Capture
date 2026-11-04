// ignore_for_file: public_member_api_docs, sort_constructors_first
// Flutter imports:
import 'package:animated_custom_dropdown/custom_dropdown.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax/iconsax.dart';

import '/theme/theme.dart';
import '/views/views.dart';

class FormFields extends StatefulWidget {
  final TextEditingController? controller;
  final void Function(String value)? onChanged;
  final String? label;
  final String? fLabel;
  final String? hintText;
  final Widget? suffix;
  final Widget? suffixIcon;
  final Widget? prefixIcon;
  final void Function()? onTap;
  final bool? readOnly;
  final Color? fillColor;
  final int? maxLines;
  final String? Function(String? input)? valid;
  final TextInputType? keyboardType;
  final bool? enabled;
  final TextInputAction? action;
  final String? value;
  final List<TextInputFormatter>? inputFormatters;
  final bool? obsecureText;
  final bool? autofocus;
  final void Function()? labelAction;
  final int? maxLength;
  final bool? isRequired;
  final EdgeInsetsGeometry? contentPadding;
  final bool? isDense;
  final TextStyle? style;

  const FormFields({
    super.key,
    this.controller,
    this.onChanged,
    this.label,
    this.fLabel,
    this.hintText,
    this.suffix,
    this.suffixIcon,
    this.prefixIcon,
    this.onTap,
    this.readOnly,
    this.fillColor,
    this.maxLines,
    this.valid,
    this.keyboardType,
    this.enabled,
    this.action,
    this.value,
    this.inputFormatters,
    this.obsecureText,
    this.autofocus,
    this.labelAction,
    this.maxLength,
    this.isRequired,
    this.contentPadding,
    this.isDense,
    this.style,
  });

  @override
  State<FormFields> createState() => _FormFieldsState();
}

class _FormFieldsState extends State<FormFields> {
  @override
  Widget build(BuildContext context) {
    TextFormField field = TextFormField(
      inputFormatters: widget.inputFormatters,
      controller: widget.controller,
      enabled: widget.enabled,
      maxLength: widget.maxLength,
      keyboardType: widget.keyboardType,
      onTap: widget.onTap,
      maxLines: widget.maxLines ?? 1,
      readOnly: widget.readOnly ?? false,
      obscureText: widget.obsecureText ?? false,
      autofocus: widget.autofocus ?? false,
      onEditingComplete: () => FocusManager.instance.primaryFocus!.unfocus(),
      onTapOutside: (event) => FocusManager.instance.primaryFocus!.unfocus(),
      onChanged: widget.onChanged,
      style:
          widget.style ??
          Theme.of(context).textTheme.bodySmall!.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w500,
          ),
      decoration: InputDecoration(
        label: widget.fLabel != null
            ? Text(widget.fLabel!, style: Theme.of(context).textTheme.bodySmall)
            : null,
        hintText: widget.hintText,
        hintStyle: Theme.of(context).textTheme.bodySmall,
        suffix: widget.suffix,
        suffixIcon: widget.suffixIcon,
        filled: true,
        fillColor: widget.fillColor ?? Theme.of(context).colorScheme.surface,
        prefixIcon: widget.prefixIcon,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(
            color: widget.fillColor != null
                ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.26)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        border: OutlineInputBorder(
          borderSide: BorderSide(
            color: widget.fillColor != null
                ? Theme.of(context).colorScheme.outline.withValues(alpha: 0.12)
                : Theme.of(context).colorScheme.outlineVariant,
          ),
          borderRadius: BorderRadius.circular(6),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: AppColors.primary),
          borderRadius: BorderRadius.circular(6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          vertical: 14, // smaller height
          horizontal: 8,
        ),
        isDense: true,
        prefixIconConstraints: const BoxConstraints(
          minWidth: 28,
          minHeight: 28,
        ),
        suffixIconConstraints: const BoxConstraints(
          minWidth: 28,
          minHeight: 28,
        ),
      ),
      validator: widget.valid,
    );
    if (widget.label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    widget.label!,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.isRequired == true) ...[
                    const SizedBox(width: 4),
                    Text(
                      '*',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              if (widget.labelAction != null) ...[
                GestureDetector(
                  onTap: widget.labelAction,
                  child: Text(
                    'Edit',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          field,
        ],
      );
    }

    return field;
  }
}

class FormMultiDropdowns extends StatefulWidget {
  final String? label;
  final bool? isRequired;
  final List<Object>? items;
  final List<Object>? selectedItems;
  final dynamic Function(List<dynamic>)? onListChanged;
  const FormMultiDropdowns({
    super.key,
    this.label,
    this.isRequired,
    this.items,
    this.selectedItems,
    this.onListChanged,
  });

  @override
  State<FormMultiDropdowns> createState() => _FormMultiDropdownsState();
}

class _FormMultiDropdownsState extends State<FormMultiDropdowns> {
  late final MultiSelectController<Object> _controller =
      MultiSelectController<Object>(widget.selectedItems ?? const []);

  void _clearSelection() {
    _controller.clear();
    widget.onListChanged?.call(const []);
  }

  @override
  Widget build(BuildContext context) {
    CustomDropdown field;

    field = CustomDropdown.multiSelectSearch(
      items: widget.items,
      multiSelectController: _controller,

      closedHeaderPadding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 11,
      ),
      decoration: CustomDropdownDecoration(
        expandedBorder: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        expandedBorderRadius: BorderRadius.circular(8),
        closedBorder: Border.all(
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        closedBorderRadius: BorderRadius.circular(8),
        closedFillColor: Theme.of(context).colorScheme.surface,
        expandedFillColor: Theme.of(context).colorScheme.surface,
      ),
      onListChanged: widget.onListChanged,
    );

    if (widget.label != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    widget.label!,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.isRequired == true) ...[
                    const SizedBox(width: 4),
                    Text(
                      '*',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
              GestureDetector(
                onTap: _clearSelection,
                child: Text(
                  'Clear',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          field,
        ],
      );
    }

    return field;
  }
}

class FormDropdownSearch extends StatefulWidget {
  final String? label;
  final bool? isRequired;
  final dynamic initialItem;
  final List<dynamic>? items;
  final Function(dynamic)? onChanged;
  final String? Function(dynamic)? validator;
  final bool allowClear;

  const FormDropdownSearch({
    super.key,
    this.label,
    this.isRequired,
    this.items,
    this.initialItem,
    this.onChanged,
    this.validator,
    this.allowClear = true,
  });

  @override
  State<FormDropdownSearch> createState() => _FormDropdownSearchState();
}

class _FormDropdownSearchState extends State<FormDropdownSearch> {
  dynamic selectedValue;

  @override
  void initState() {
    super.initState();
    selectedValue = widget.initialItem;
  }

  @override
  void didUpdateWidget(covariant FormDropdownSearch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialItem != oldWidget.initialItem) {
      selectedValue = widget.initialItem;
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return FormField<dynamic>(
      validator: widget.validator,
      initialValue: selectedValue,
      builder: (field) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Label
            if (widget.label != null) ...[
              Row(
                children: [
                  Text(
                    widget.label!,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (widget.isRequired == true)
                    Text(
                      ' *',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
            ],

            // Dropdown
            CustomSearchableDropdown(
              key: ValueKey('dropdown_${widget.items?.length}_${widget.items?.hashCode}'),
              initialValue: selectedValue,
              items: widget.items ?? [],
              itemAsString: (s) => s,
              showClearButton: widget.allowClear,
              onChanged: (value) {
                setState(() => selectedValue = value);
                field.didChange(value);
                widget.onChanged?.call(value);
              },
            ),

            // Error message
            if (field.hasError)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  field.errorText!,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: AppColors.danger),
                ),
              ),
          ],
        );
      },
    );
  }
}

class ListingSearchField extends StatelessWidget {
  final String? pageTitle;
  final void Function(String)? onChanged;
  const ListingSearchField({super.key, this.pageTitle, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onChanged: onChanged,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        height: 1.0, // tighter line height
      ),
      decoration: InputDecoration(
        hintText: 'Search ${pageTitle ?? ''}',
        hintStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 8, right: 4),
          child: Icon(
            Iconsax.search_normal,
            size: 13, // smaller icon
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 28,
          minHeight: 28,
        ),
        isDense: true, // reduces default height
        contentPadding: const EdgeInsets.symmetric(
          vertical: 6, // smaller height
          horizontal: 8,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6), // small corner radius
          borderSide: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: Theme.of(
              context,
            ).colorScheme.outline.withValues(alpha: 0.12),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(6),
          borderSide: BorderSide(
            color: Theme.of(context).colorScheme.primary,
            width: 1,
          ),
        ),
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
      ),
    );
  }
}
