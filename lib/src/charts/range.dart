part of excel;

class Range {
  final String? name;
  final CellIndex startCell;
  final CellIndex endCell;

  Range({
    this.name,
    required this.startCell,
    required this.endCell,
  });

  /// A1:A2 => $A$1:$A$2
  /// AA112:AA113 => $AA$112:$AA$113
  String chartString() {
    return "${startCell.cellId.splitMapJoin(
      RegExp(r'\d+|[a-zA-Z]+'),
      onMatch: (m) => '\$${m.group(0)}',
      onNonMatch: (n) => '',
    )}:${endCell.cellId.splitMapJoin(
      RegExp(r'\d+|[a-zA-Z]+'),
      onMatch: (m) => '\$${m.group(0)}',
      onNonMatch: (n) => '',
    )}";
  }
}
