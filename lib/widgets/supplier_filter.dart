/*
SUPPLIER ORIGIN FILTER CHIPS

THREE OPTIONS:
1. ALL SUPPLIERS: Shows everything
2. Nigeria-only: Nigerian products
3. Korea-only: Korean products
*/

import 'package:flutter/material.dart';

const _flagNigeria = '\u{1F1F3}\u{1F1EC}';
const _flagKorea = '\u{1F1F0}\u{1F1F7}';

class SupplierFilter extends StatefulWidget {
  final String selectedFilter; // 'all', 'nigeria', 'korea'
  final ValueChanged<String> onFilterChanged;
  final bool isLoading;

  const SupplierFilter({
    super.key,
    required this.selectedFilter,
    required this.onFilterChanged,
    this.isLoading = false,
  });

  @override
  State<SupplierFilter> createState() => SupplierFilterState();
}

class SupplierFilterState extends State<SupplierFilter> {
  late String _currentFilter;

  @override
  void initState() {
    super.initState();
    _currentFilter = widget.selectedFilter;
  }

  @override
  void didUpdateWidget(covariant SupplierFilter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedFilter != widget.selectedFilter &&
        _currentFilter != widget.selectedFilter) {
      _currentFilter = widget.selectedFilter;
    }
  }

  void _onChipSelected(String filter) {
    if (widget.isLoading) return;
    if (_currentFilter == filter) return;

    setState(() {
      _currentFilter = filter;
    });
    widget.onFilterChanged(filter);
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ChoiceChip(
          label: const Text('All'),
          selected: _currentFilter == 'all',
          onSelected: (_) => _onChipSelected('all'),
          selectedColor: Colors.blue,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: _currentFilter == 'all' ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('$_flagNigeria Nigeria'),
          selected: _currentFilter == 'nigeria',
          onSelected: (_) => _onChipSelected('nigeria'),
          selectedColor: Colors.blue,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: _currentFilter == 'nigeria' ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(width: 8),
        ChoiceChip(
          label: const Text('$_flagKorea Korea'),
          selected: _currentFilter == 'korea',
          onSelected: (_) => _onChipSelected('korea'),
          selectedColor: Colors.blue,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
            color: _currentFilter == 'korea' ? Colors.white : Colors.black,
          ),
        ),
      ],
    );
  }
}
