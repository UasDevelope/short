import 'package:flutter/material.dart';

class FilterSelector extends StatelessWidget {
  final List<String> filters;
  final String? selectedFilter;
  final void Function(String) onFilterSelected;
  const FilterSelector({Key? key, required this.filters, this.selectedFilter, required this.onFilterSelected}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          return ChoiceChip(
            label: Text(filter),
            selected: selectedFilter == filter,
            onSelected: (_) => onFilterSelected(filter),
          );
        },
      ),
    );
  }
} 