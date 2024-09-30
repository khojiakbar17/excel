part of excel;

class Save {
  final Excel _excel;
  final Map<String, ArchiveFile> _archiveFiles = {};
  final List<CellStyle> _innerCellStyle = [];
  final Parser parser;

  var _drawingsCount = 0;
  var _chartsCount = 0;

  Save._(this._excel, this.parser);

  void _addNewColumn(XmlElement columns, int min, int max, double width) {
    columns.children.add(XmlElement(XmlName('col'), [
      XmlAttribute(XmlName('min'), (min + 1).toString()),
      XmlAttribute(XmlName('max'), (max + 1).toString()),
      XmlAttribute(XmlName('width'), width.toStringAsFixed(2)),
      XmlAttribute(XmlName('bestFit'), "1"),
      XmlAttribute(XmlName('customWidth'), "1"),
    ], []));
  }

  double _calcAutoFitColumnWidth(Sheet sheet, int column) {
    var maxNumOfCharacters = 0;
    sheet._sheetData.forEach((key, value) {
      if (value.containsKey(column) &&
          value[column]!.value is! FormulaCellValue) {
        maxNumOfCharacters =
            max(value[column]!.value.toString().length, maxNumOfCharacters);
      }
    });

    return ((maxNumOfCharacters * 7.0 + 9.0) / 7.0 * 256).truncate() / 256;
  }

  /*   XmlElement _replaceCell(String sheet, XmlElement row, XmlElement lastCell,
      int columnIndex, int rowIndex, CellValue? value) {
    var index = lastCell == null ? 0 : row.children.indexOf(lastCell);
    var cell = _createCell(sheet, columnIndex, rowIndex, value);
    row.children
      ..removeAt(index)
      ..insert(index, cell);
    return cell;
  } */

  // Manage value's type
  XmlElement _createCell(String sheet, int columnIndex, int rowIndex,
      CellValue? value, NumFormat? numberFormat) {
    SharedString? sharedString;
    if (value is TextCellValue) {
      sharedString = _excel._sharedStrings.tryFind(value.toString());
      if (sharedString != null) {
        _excel._sharedStrings.add(sharedString, value.toString());
      } else {
        sharedString = _excel._sharedStrings.addFromString(value.toString());
      }
    }

    String rC = getCellId(columnIndex, rowIndex);

    var attributes = <XmlAttribute>[
      XmlAttribute(XmlName('r'), rC),
      if (value is TextCellValue) XmlAttribute(XmlName('t'), 's'),
      if (value is BoolCellValue) XmlAttribute(XmlName('t'), 'b'),
    ];

    final cellStyle =
        _excel._sheetMap[sheet]?._sheetData[rowIndex]?[columnIndex]?.cellStyle;

    if (_excel._styleChanges && cellStyle != null) {
      int upperLevelPos = _checkPosition(_excel._cellStyleList, cellStyle);
      if (upperLevelPos == -1) {
        int lowerLevelPos = _checkPosition(_innerCellStyle, cellStyle);
        if (lowerLevelPos != -1) {
          upperLevelPos = lowerLevelPos + _excel._cellStyleList.length;
        } else {
          upperLevelPos = 0;
        }
      }
      attributes.insert(
        1,
        XmlAttribute(XmlName('s'), '$upperLevelPos'),
      );
    } else if (_excel._cellStyleReferenced.containsKey(sheet) &&
        _excel._cellStyleReferenced[sheet]!.containsKey(rC)) {
      attributes.insert(
        1,
        XmlAttribute(
            XmlName('s'), '${_excel._cellStyleReferenced[sheet]![rC]}'),
      );
    }

    // TODO track & write the numFmts/numFmt to styles.xml if used
    final List<XmlElement> children;
    switch (value) {
      case null:
        children = [];
      case FormulaCellValue():
        children = [
          XmlElement(XmlName('f'), [], [XmlText(value.formula)]),
          XmlElement(XmlName('v'), [], [XmlText('')]),
        ];
      case IntCellValue():
        final String v = switch (numberFormat) {
          NumericNumFormat() => numberFormat.writeInt(value),
          _ => throw Exception(
              '$numberFormat does not work for ${value.runtimeType}'),
        };
        children = [
          XmlElement(XmlName('v'), [], [XmlText(v)]),
        ];
      case DoubleCellValue():
        final String v = switch (numberFormat) {
          NumericNumFormat() => numberFormat.writeDouble(value),
          _ => throw Exception(
              '$numberFormat does not work for ${value.runtimeType}'),
        };
        children = [
          XmlElement(XmlName('v'), [], [XmlText(v)]),
        ];
      case DateTimeCellValue():
        final String v = switch (numberFormat) {
          DateTimeNumFormat() => numberFormat.writeDateTime(value),
          _ => throw Exception(
              '$numberFormat does not work for ${value.runtimeType}'),
        };
        children = [
          XmlElement(XmlName('v'), [], [XmlText(v)]),
        ];
      case DateCellValue():
        final String v = switch (numberFormat) {
          DateTimeNumFormat() => numberFormat.writeDate(value),
          _ => throw Exception(
              '$numberFormat does not work for ${value.runtimeType}'),
        };
        children = [
          XmlElement(XmlName('v'), [], [XmlText(v)]),
        ];
      case TimeCellValue():
        final String v = switch (numberFormat) {
          TimeNumFormat() => numberFormat.writeTime(value),
          _ => throw Exception(
              '$numberFormat does not work for ${value.runtimeType}'),
        };
        children = [
          XmlElement(XmlName('v'), [], [XmlText(v)]),
        ];
      case TextCellValue():
        children = [
          XmlElement(XmlName('v'), [], [
            XmlText(_excel._sharedStrings.indexOf(sharedString!).toString())
          ]),
        ];
      case BoolCellValue():
        children = [
          XmlElement(XmlName('v'), [], [XmlText(value.value ? '1' : '0')]),
        ];
    }

    return XmlElement(XmlName('c'), attributes, children);
  }

  /// Create a new row in the sheet.
  XmlElement _createNewRow(XmlElement table, int rowIndex, double? height) {
    var row = XmlElement(XmlName('row'), [
      XmlAttribute(XmlName('r'), (rowIndex + 1).toString()),
      if (height != null)
        XmlAttribute(XmlName('ht'), height.toStringAsFixed(2)),
      if (height != null) XmlAttribute(XmlName('customHeight'), '1'),
    ], []);
    table.children.add(row);
    return row;
  }

  /// Writing Font Color in [xl/styles.xml] from the Cells of the sheets.

  void _processStylesFile() {
    _innerCellStyle.clear();
    List<String> innerPatternFill = <String>[];
    List<_FontStyle> innerFontStyle = <_FontStyle>[];
    List<_BorderSet> innerBorderSet = <_BorderSet>[];

    _excel._sheetMap.forEach((sheetName, sheetObject) {
      sheetObject._sheetData.forEach((_, columnMap) {
        columnMap.forEach((_, dataObject) {
          if (dataObject.cellStyle != null) {
            int pos = _checkPosition(_innerCellStyle, dataObject.cellStyle!);
            if (pos == -1) {
              _innerCellStyle.add(dataObject.cellStyle!);
            }
          }
        });
      });
    });

    _innerCellStyle.forEach((cellStyle) {
      _FontStyle _fs = _FontStyle(
          bold: cellStyle.isBold,
          italic: cellStyle.isItalic,
          fontColorHex: cellStyle.fontColor,
          underline: cellStyle.underline,
          fontSize: cellStyle.fontSize,
          fontFamily: cellStyle.fontFamily,
          fontScheme: cellStyle.fontScheme);

      /// If `-1` is returned then it indicates that `_fontStyle` is not present in the `_fs`
      if (_fontStyleIndex(_excel._fontStyleList, _fs) == -1 &&
          _fontStyleIndex(innerFontStyle, _fs) == -1) {
        innerFontStyle.add(_fs);
      }

      /// Filling the inner usable extra list of background color
      String backgroundColor = cellStyle.backgroundColor.colorHex;
      if (!_excel._patternFill.contains(backgroundColor) &&
          !innerPatternFill.contains(backgroundColor)) {
        innerPatternFill.add(backgroundColor);
      }

      final _bs = _createBorderSetFromCellStyle(cellStyle);
      if (!_excel._borderSetList.contains(_bs) &&
          !innerBorderSet.contains(_bs)) {
        innerBorderSet.add(_bs);
      }
    });

    XmlElement fonts =
        _excel._xmlFiles['xl/styles.xml']!.findAllElements('fonts').first;

    var fontAttribute = fonts.getAttributeNode('count');
    if (fontAttribute != null) {
      fontAttribute.value =
          '${_excel._fontStyleList.length + innerFontStyle.length}';
    } else {
      fonts.attributes.add(XmlAttribute(XmlName('count'),
          '${_excel._fontStyleList.length + innerFontStyle.length}'));
    }

    innerFontStyle.forEach((fontStyleElement) {
      fonts.children.add(XmlElement(XmlName('font'), [], [
        /// putting color
        if (fontStyleElement._fontColorHex != null &&
            fontStyleElement._fontColorHex!.colorHex != "FF000000")
          XmlElement(XmlName('color'), [
            XmlAttribute(
                XmlName('rgb'), fontStyleElement._fontColorHex!.colorHex)
          ], []),

        /// putting bold
        if (fontStyleElement.isBold) XmlElement(XmlName('b'), [], []),

        /// putting italic
        if (fontStyleElement.isItalic) XmlElement(XmlName('i'), [], []),

        /// putting single underline
        if (fontStyleElement.underline != Underline.None &&
            fontStyleElement.underline == Underline.Single)
          XmlElement(XmlName('u'), [], []),

        /// putting double underline
        if (fontStyleElement.underline != Underline.None &&
            fontStyleElement.underline != Underline.Single &&
            fontStyleElement.underline == Underline.Double)
          XmlElement(
              XmlName('u'), [XmlAttribute(XmlName('val'), 'double')], []),

        /// putting fontFamily
        if (fontStyleElement.fontFamily != null &&
            fontStyleElement.fontFamily!.toLowerCase().toString() != 'null' &&
            fontStyleElement.fontFamily != '' &&
            fontStyleElement.fontFamily!.isNotEmpty)
          XmlElement(XmlName('name'), [
            XmlAttribute(XmlName('val'), fontStyleElement.fontFamily.toString())
          ], []),

        /// putting fontScheme
        if (fontStyleElement.fontScheme != FontScheme.Unset)
          XmlElement(XmlName('scheme'), [
            XmlAttribute(
                XmlName('val'),
                switch (fontStyleElement.fontScheme) {
                  FontScheme.Major => "major",
                  _ => "minor"
                })
          ], []),

        /// putting fontSize
        if (fontStyleElement.fontSize != null &&
            fontStyleElement.fontSize.toString().isNotEmpty)
          XmlElement(XmlName('sz'), [
            XmlAttribute(XmlName('val'), fontStyleElement.fontSize.toString())
          ], []),
      ]));
    });

    XmlElement fills =
        _excel._xmlFiles['xl/styles.xml']!.findAllElements('fills').first;

    var fillAttribute = fills.getAttributeNode('count');

    if (fillAttribute != null) {
      fillAttribute.value =
          '${_excel._patternFill.length + innerPatternFill.length}';
    } else {
      fills.attributes.add(XmlAttribute(XmlName('count'),
          '${_excel._patternFill.length + innerPatternFill.length}'));
    }

    innerPatternFill.forEach((color) {
      if (color.length >= 2) {
        if (color.substring(0, 2).toUpperCase() == 'FF') {
          fills.children.add(XmlElement(XmlName('fill'), [], [
            XmlElement(XmlName('patternFill'), [
              XmlAttribute(XmlName('patternType'), 'solid')
            ], [
              XmlElement(XmlName('fgColor'),
                  [XmlAttribute(XmlName('rgb'), color)], []),
              XmlElement(
                  XmlName('bgColor'), [XmlAttribute(XmlName('rgb'), color)], [])
            ])
          ]));
        } else if (color == "none" ||
            color == "gray125" ||
            color == "lightGray") {
          fills.children.add(XmlElement(XmlName('fill'), [], [
            XmlElement(XmlName('patternFill'),
                [XmlAttribute(XmlName('patternType'), color)], [])
          ]));
        }
      } else {
        _damagedExcel(
            text:
                "Corrupted Styles Found. Can't process further, Open up issue in github.");
      }
    });

    XmlElement borders =
        _excel._xmlFiles['xl/styles.xml']!.findAllElements('borders').first;
    var borderAttribute = borders.getAttributeNode('count');

    if (borderAttribute != null) {
      borderAttribute.value =
          '${_excel._borderSetList.length + innerBorderSet.length}';
    } else {
      borders.attributes.add(XmlAttribute(XmlName('count'),
          '${_excel._borderSetList.length + innerBorderSet.length}'));
    }

    innerBorderSet.forEach((border) {
      var borderElement = XmlElement(XmlName('border'));
      if (border.diagonalBorderDown) {
        borderElement.attributes
            .add(XmlAttribute(XmlName('diagonalDown'), '1'));
      }
      if (border.diagonalBorderUp) {
        borderElement.attributes.add(XmlAttribute(XmlName('diagonalUp'), '1'));
      }
      final Map<String, Border> borderMap = {
        'left': border.leftBorder,
        'right': border.rightBorder,
        'top': border.topBorder,
        'bottom': border.bottomBorder,
        'diagonal': border.diagonalBorder,
      };
      for (var key in borderMap.keys) {
        final borderValue = borderMap[key]!;

        final element = XmlElement(XmlName(key));
        final style = borderValue.borderStyle;
        if (style != null) {
          element.attributes.add(XmlAttribute(XmlName('style'), style.style));
        }
        final color = borderValue.borderColorHex;
        if (color != null) {
          element.children.add(XmlElement(
              XmlName('color'), [XmlAttribute(XmlName('rgb'), color)]));
        }
        borderElement.children.add(element);
      }

      borders.children.add(borderElement);
    });

    final styleSheet = _excel._xmlFiles['xl/styles.xml']!;

    XmlElement celx = styleSheet.findAllElements('cellXfs').first;
    var cellAttribute = celx.getAttributeNode('count');

    if (cellAttribute != null) {
      cellAttribute.value =
          '${_excel._cellStyleList.length + _innerCellStyle.length}';
    } else {
      celx.attributes.add(XmlAttribute(XmlName('count'),
          '${_excel._cellStyleList.length + _innerCellStyle.length}'));
    }

    _innerCellStyle.forEach((cellStyle) {
      String backgroundColor = cellStyle.backgroundColor.colorHex;

      _FontStyle _fs = _FontStyle(
          bold: cellStyle.isBold,
          italic: cellStyle.isItalic,
          fontColorHex: cellStyle.fontColor,
          underline: cellStyle.underline,
          fontSize: cellStyle.fontSize,
          fontFamily: cellStyle.fontFamily);

      HorizontalAlign horizontalAlign = cellStyle.horizontalAlignment;
      VerticalAlign verticalAlign = cellStyle.verticalAlignment;
      int rotation = cellStyle.rotation;
      TextWrapping? textWrapping = cellStyle.wrap;
      int backgroundIndex = innerPatternFill.indexOf(backgroundColor),
          fontIndex = _fontStyleIndex(innerFontStyle, _fs);
      _BorderSet _bs = _createBorderSetFromCellStyle(cellStyle);
      int borderIndex = innerBorderSet.indexOf(_bs);

      final numberFormat = cellStyle.numberFormat;
      final int numFmtId = switch (numberFormat) {
        StandardNumFormat() => numberFormat.numFmtId,
        CustomNumFormat() => _excel._numFormats.findOrAdd(numberFormat),
      };

      var attributes = <XmlAttribute>[
        XmlAttribute(XmlName('borderId'),
            '${borderIndex == -1 ? 0 : borderIndex + _excel._borderSetList.length}'),
        XmlAttribute(XmlName('fillId'),
            '${backgroundIndex == -1 ? 0 : backgroundIndex + _excel._patternFill.length}'),
        XmlAttribute(XmlName('fontId'),
            '${fontIndex == -1 ? 0 : fontIndex + _excel._fontStyleList.length}'),
        XmlAttribute(XmlName('numFmtId'), numFmtId.toString()),
        XmlAttribute(XmlName('xfId'), '0'),
      ];

      if ((_excel._patternFill.contains(backgroundColor) ||
              innerPatternFill.contains(backgroundColor)) &&
          backgroundColor != "none" &&
          backgroundColor != "gray125" &&
          backgroundColor.toLowerCase() != "lightgray") {
        attributes.add(XmlAttribute(XmlName('applyFill'), '1'));
      }

      if (_fontStyleIndex(_excel._fontStyleList, _fs) != -1 &&
          _fontStyleIndex(innerFontStyle, _fs) != -1) {
        attributes.add(XmlAttribute(XmlName('applyFont'), '1'));
      }

      var children = <XmlElement>[];

      if (horizontalAlign != HorizontalAlign.Left ||
          textWrapping != null ||
          verticalAlign != VerticalAlign.Bottom ||
          rotation != 0) {
        attributes.add(XmlAttribute(XmlName('applyAlignment'), '1'));
        var childAttributes = <XmlAttribute>[];

        if (textWrapping != null) {
          childAttributes.add(XmlAttribute(
              XmlName(textWrapping == TextWrapping.Clip
                  ? 'shrinkToFit'
                  : 'wrapText'),
              '1'));
        }

        if (verticalAlign != VerticalAlign.Bottom) {
          String ver = verticalAlign == VerticalAlign.Top ? 'top' : 'center';
          childAttributes.add(XmlAttribute(XmlName('vertical'), '$ver'));
        }

        if (horizontalAlign != HorizontalAlign.Left) {
          String hor =
              horizontalAlign == HorizontalAlign.Right ? 'right' : 'center';
          childAttributes.add(XmlAttribute(XmlName('horizontal'), '$hor'));
        }
        if (rotation != 0) {
          childAttributes
              .add(XmlAttribute(XmlName('textRotation'), '$rotation'));
        }

        children.add(XmlElement(XmlName('alignment'), childAttributes, []));
      }

      celx.children.add(XmlElement(XmlName('xf'), attributes, children));
    });

    final customNumberFormats = _excel._numFormats._map.entries
        .map<MapEntry<int, CustomNumFormat>?>((e) {
          final format = e.value;
          if (format is! CustomNumFormat) {
            return null;
          }
          return MapEntry<int, CustomNumFormat>(e.key, format);
        })
        .whereNotNull()
        .sorted((a, b) => a.key.compareTo(b.key));

    if (customNumberFormats.isNotEmpty) {
      var numFmtsElement = styleSheet
          .findAllElements('numFmts')
          .whereType<XmlElement>()
          .firstOrNull;
      int count;
      if (numFmtsElement == null) {
        numFmtsElement = XmlElement(XmlName('numFmts'));

        ///FIX: if no default numFormats were added in styles.xml - customNumFormats were added in wrong place,
        styleSheet
            .findElements('styleSheet')
            .first
            .children
            .insert(0, numFmtsElement);
        // styleSheet.children.insert(0, numFmtsElement);
      }
      count = int.parse(numFmtsElement.getAttribute('count') ?? '0');

      for (var numFormat in customNumberFormats) {
        final numFmtIdString = numFormat.key.toString();
        final formatCode = numFormat.value.formatCode;
        var numFmtElement = numFmtsElement.children
            .whereType<XmlElement>()
            .firstWhereOrNull((node) =>
                node.name.local == 'numFmt' &&
                node.getAttribute('numFmtId') == numFmtIdString);
        if (numFmtElement == null) {
          numFmtElement = XmlElement(
              XmlName('numFmt'),
              [
                XmlAttribute(XmlName('numFmtId'), numFmtIdString),
                XmlAttribute(XmlName('formatCode'), formatCode),
              ],
              [],
              true);
          numFmtsElement.children.add(numFmtElement);
          count++;
        } else if ((numFmtElement.getAttribute('formatCode') ?? '') !=
            formatCode) {
          numFmtElement.setAttribute('formatCode', formatCode);
        }
      }

      numFmtsElement.setAttribute('count', count.toString());
    }
  }

  List<int>? _save() {
    if (_excel._styleChanges) {
      _processStylesFile();
    }
    _setSheetElements();
    if (_excel._defaultSheet != null) {
      _setDefaultSheet(_excel._defaultSheet);
    }
    _setSharedStrings();

    if (_excel._mergeChanges) {
      _setMerge();
    }

    if (_excel._rtlChanges) {
      _setRTL();
    }

    for (var xmlFile in _excel._xmlFiles.keys) {
      var xml = _excel._xmlFiles[xmlFile].toString();
      var content = utf8.encode(xml);

      _archiveFiles[xmlFile] = ArchiveFile(xmlFile, content.length, content);
    }
    return ZipEncoder().encode(_cloneArchive(_excel._archive, _archiveFiles));
  }

  void _setColumns(Sheet sheetObject, XmlDocument xmlFile) {
    final columnElements = xmlFile.findAllElements('cols');

    if (sheetObject.getColumnWidths.isEmpty &&
        sheetObject.getColumnAutoFits.isEmpty) {
      if (columnElements.isEmpty) {
        return;
      }

      final columns = columnElements.first;
      final worksheet = xmlFile.findAllElements('worksheet').first;
      worksheet.children.remove(columns);
      return;
    }

    if (columnElements.isEmpty) {
      final worksheet = xmlFile.findAllElements('worksheet').first;
      final sheetData = xmlFile.findAllElements('sheetData').first;
      final index = worksheet.children.indexOf(sheetData);

      worksheet.children.insert(index, XmlElement(XmlName('cols'), [], []));
    }

    var columns = columnElements.first;

    if (columns.children.isNotEmpty) {
      columns.children.clear();
    }

    final autoFits = sheetObject.getColumnAutoFits;
    final customWidths = sheetObject.getColumnWidths;

    final columnCount = max(
        autoFits.isEmpty ? 0 : autoFits.keys.reduce(max) + 1,
        customWidths.isEmpty ? 0 : customWidths.keys.reduce(max) + 1);

    List<double> columnWidths = <double>[];

    double defaultColumnWidth =
        sheetObject.defaultColumnWidth ?? _excelDefaultColumnWidth;

    for (var index = 0; index < columnCount; index++) {
      double width = defaultColumnWidth;

      if (autoFits.containsKey(index) && (!customWidths.containsKey(index))) {
        width = _calcAutoFitColumnWidth(sheetObject, index);
      } else {
        if (customWidths.containsKey(index)) {
          width = customWidths[index]!;
        }
      }

      columnWidths.add(width);

      _addNewColumn(columns, index, index, width);
    }
  }

  void _setRows(String sheetName, Sheet sheetObject) {
    final customHeights = sheetObject.getRowHeights;

    for (var rowIndex = 0; rowIndex < sheetObject._maxRows; rowIndex++) {
      double? height;

      if (customHeights.containsKey(rowIndex)) {
        height = customHeights[rowIndex];
      }

      if (sheetObject._sheetData[rowIndex] == null) {
        continue;
      }
      var foundRow = _createNewRow(
          _excel._sheets[sheetName]! as XmlElement, rowIndex, height);
      for (var columnIndex = 0;
          columnIndex < sheetObject._maxColumns;
          columnIndex++) {
        var data = sheetObject._sheetData[rowIndex]![columnIndex];
        if (data == null) {
          continue;
        }
        _updateCell(sheetName, foundRow, columnIndex, rowIndex, data.value,
            data.cellStyle?.numberFormat);
      }
    }
  }

  bool _setDefaultSheet(String? sheetName) {
    if (sheetName == null || _excel._xmlFiles['xl/workbook.xml'] == null) {
      return false;
    }
    List<XmlElement> sheetList =
        _excel._xmlFiles['xl/workbook.xml']!.findAllElements('sheet').toList();
    XmlElement elementFound = XmlElement(XmlName(''));

    int position = -1;
    for (int i = 0; i < sheetList.length; i++) {
      var _sheetName = sheetList[i].getAttribute('name');
      if (_sheetName != null && _sheetName.toString() == sheetName) {
        elementFound = sheetList[i];
        position = i;
        break;
      }
    }

    if (position == -1) {
      return false;
    }
    if (position == 0) {
      return true;
    }

    _excel._xmlFiles['xl/workbook.xml']!
        .findAllElements('sheets')
        .first
        .children
      ..removeAt(position)
      ..insert(0, elementFound);

    String? expectedSheet = _excel._getDefaultSheet();

    return expectedSheet == sheetName;
  }

  void _setHeaderFooter(String sheetName) {
    final sheet = _excel._sheetMap[sheetName];
    if (sheet == null) return;

    final xmlFile = _excel._xmlFiles[_excel._xmlSheetId[sheetName]];
    if (xmlFile == null) return;

    final sheetXmlElement = xmlFile.findAllElements("worksheet").first;

    final results = sheetXmlElement.findAllElements("headerFooter");
    if (results.isNotEmpty) {
      sheetXmlElement.children.remove(results.first);
    }

    if (sheet.headerFooter == null) return;

    sheetXmlElement.children.add(sheet.headerFooter!.toXmlElement());
  }

  /// Writing the merged cells information into the excel properties files.
  void _setMerge() {
    _selfCorrectSpanMap(_excel);
    _excel._mergeChangeLook.forEach((s) {
      if (_excel._sheetMap[s] != null &&
          _excel._sheetMap[s]!._spanList.isNotEmpty &&
          _excel._xmlSheetId.containsKey(s) &&
          _excel._xmlFiles.containsKey(_excel._xmlSheetId[s])) {
        Iterable<XmlElement>? iterMergeElement = _excel
            ._xmlFiles[_excel._xmlSheetId[s]]
            ?.findAllElements('mergeCells');
        late XmlElement mergeElement;
        if (iterMergeElement?.isNotEmpty ?? false) {
          mergeElement = iterMergeElement!.first;
        } else {
          if ((_excel._xmlFiles[_excel._xmlSheetId[s]]
                      ?.findAllElements('worksheet')
                      .length ??
                  0) >
              0) {
            int index = _excel._xmlFiles[_excel._xmlSheetId[s]]!
                .findAllElements('worksheet')
                .first
                .children
                .indexOf(_excel._xmlFiles[_excel._xmlSheetId[s]]!
                    .findAllElements("sheetData")
                    .first);
            if (index == -1) {
              _damagedExcel();
            }
            _excel._xmlFiles[_excel._xmlSheetId[s]]!
                .findAllElements('worksheet')
                .first
                .children
                .insert(
                    index + 1,
                    XmlElement(XmlName('mergeCells'),
                        [XmlAttribute(XmlName('count'), '0')]));

            mergeElement = _excel._xmlFiles[_excel._xmlSheetId[s]]!
                .findAllElements('mergeCells')
                .first;
          } else {
            _damagedExcel();
          }
        }

        List<String> _spannedItems =
            List<String>.from(_excel._sheetMap[s]!.spannedItems);

        [
          ['count', _spannedItems.length.toString()],
        ].forEach((value) {
          if (mergeElement.getAttributeNode(value[0]) == null) {
            mergeElement.attributes
                .add(XmlAttribute(XmlName(value[0]), value[1]));
          } else {
            mergeElement.getAttributeNode(value[0])!.value = value[1];
          }
        });

        mergeElement.children.clear();

        _spannedItems.forEach((value) {
          mergeElement.children.add(XmlElement(XmlName('mergeCell'),
              [XmlAttribute(XmlName('ref'), '$value')], []));
        });
      }
    });
  }

  // slow implementation
  /*XmlElement _findRowByIndex(XmlElement table, int rowIndex) {
    XmlElement row;
    var rows = _findRows(table);

    var currentIndex = 0;
    for (var currentRow in rows) {
      currentIndex = _getRowNumber(currentRow) - 1;
      if (currentIndex >= rowIndex) {
        row = currentRow;
        break;
      }
    }

    // Create row if required
    if (row == null || currentIndex != rowIndex) {
      row = __insertRow(table, row, rowIndex);
    }

    return row;
  }

  XmlElement _createRow(int rowIndex) {
    return XmlElement(XmlName('row'),
        [XmlAttribute(XmlName('r'), (rowIndex + 1).toString())], []);
  }

  XmlElement __insertRow(XmlElement table, XmlElement lastRow, int rowIndex) {
    var row = _createRow(rowIndex);
    if (lastRow == null) {
      table.children.add(row);
    } else {
      var index = table.children.indexOf(lastRow);
      table.children.insert(index, row);
    }
    return row;
  }*/

  void _setRTL() {
    _excel._rtlChangeLook.forEach((s) {
      var sheetObject = _excel._sheetMap[s];
      if (sheetObject != null &&
          _excel._xmlSheetId.containsKey(s) &&
          _excel._xmlFiles.containsKey(_excel._xmlSheetId[s])) {
        var itrSheetViewsRTLElement = _excel._xmlFiles[_excel._xmlSheetId[s]]
            ?.findAllElements('sheetViews');

        if (itrSheetViewsRTLElement?.isNotEmpty ?? false) {
          var itrSheetViewRTLElement = _excel._xmlFiles[_excel._xmlSheetId[s]]
              ?.findAllElements('sheetView');

          if (itrSheetViewRTLElement?.isNotEmpty ?? false) {
            /// clear all the children of the sheetViews here

            _excel._xmlFiles[_excel._xmlSheetId[s]]
                ?.findAllElements('sheetViews')
                .first
                .children
                .clear();
          }

          _excel._xmlFiles[_excel._xmlSheetId[s]]
              ?.findAllElements('sheetViews')
              .first
              .children
              .add(XmlElement(
                XmlName('sheetView'),
                [
                  if (sheetObject.isRTL)
                    XmlAttribute(XmlName('rightToLeft'), '1'),
                  XmlAttribute(XmlName('workbookViewId'), '0'),
                ],
              ));
        } else {
          _excel._xmlFiles[_excel._xmlSheetId[s]]
              ?.findAllElements('worksheet')
              .first
              .children
              .add(XmlElement(XmlName('sheetViews'), [], [
                XmlElement(
                  XmlName('sheetView'),
                  [
                    if (sheetObject.isRTL)
                      XmlAttribute(XmlName('rightToLeft'), '1'),
                    XmlAttribute(XmlName('workbookViewId'), '0'),
                  ],
                )
              ]));
        }
      }
    });
  }

  /// Writing the value of excel cells into the separate
  /// sharedStrings file so as to minimize the size of excel files.
  void _setSharedStrings() {
    var uniqueCount = 0;
    var count = 0;

    XmlElement shareString = _excel
        ._xmlFiles['xl/${_excel._sharedStringsTarget}']!
        .findAllElements('sst')
        .first;

    shareString.children.clear();

    _excel._sharedStrings._map.forEach((string, ss) {
      uniqueCount += 1;
      count += ss.count;

      shareString.children.add(string.node);
    });

    [
      ['count', '$count'],
      ['uniqueCount', '$uniqueCount']
    ].forEach((value) {
      if (shareString.getAttributeNode(value[0]) == null) {
        shareString.attributes.add(XmlAttribute(XmlName(value[0]), value[1]));
      } else {
        shareString.getAttributeNode(value[0])!.value = value[1];
      }
    });
  }

  /// Writing cell contained text into the excel sheet files.
  /// Main method to save all sheet elements, including charts and drawings.
  void _setSheetElements() {
    _excel._sharedStrings.clear();

    _excel._sheetMap.forEach((sheetName, sheetObject) {
      if (_excel._sheets[sheetName] == null) {
        parser._createSheet(sheetName);
      }

      if (_excel._sheets[sheetName]?.children.isNotEmpty ?? false) {
        _excel._sheets[sheetName]!.children.clear();
      }

      XmlDocument? xmlFile = _excel._xmlFiles[_excel._xmlSheetId[sheetName]];
      if (xmlFile == null) return;

      double? defaultRowHeight = sheetObject.defaultRowHeight;
      double? defaultColumnWidth = sheetObject.defaultColumnWidth;

      XmlElement worksheetElement = xmlFile.findAllElements('worksheet').first;

      XmlElement? sheetFormatPrElement =
          worksheetElement.findElements('sheetFormatPr').isNotEmpty
              ? worksheetElement.findElements('sheetFormatPr').first
              : null;

      if (sheetFormatPrElement != null) {
        sheetFormatPrElement.attributes.clear();

        if (defaultRowHeight == null && defaultColumnWidth == null) {
          worksheetElement.children.remove(sheetFormatPrElement);
        }
      } else if (defaultRowHeight != null || defaultColumnWidth != null) {
        sheetFormatPrElement = XmlElement(XmlName('sheetFormatPr'), [], []);
        worksheetElement.children.insert(0, sheetFormatPrElement);
      }

      if (defaultRowHeight != null) {
        sheetFormatPrElement!.attributes.add(XmlAttribute(
            XmlName('defaultRowHeight'), defaultRowHeight.toStringAsFixed(2)));
      }
      if (defaultColumnWidth != null) {
        sheetFormatPrElement!.attributes.add(XmlAttribute(
            XmlName('defaultColWidth'), defaultColumnWidth.toStringAsFixed(2)));
      }

      _setColumns(sheetObject, xmlFile);
      _setRows(sheetName, sheetObject);
      _setHeaderFooter(sheetName);
      _setDrawingsAndCharts(sheetName, sheetObject, xmlFile); // Updated
    });
  }

  /// Serializes the drawings and charts associated with a sheet.
  void _setDrawingsAndCharts(
    String sheetName,
    Sheet sheetObject,
    XmlDocument xmlFile,
  ) {
    if (sheetObject._drawing == null) return;

    // Create or get the drawing XML element
    XmlElement worksheetElement = xmlFile.findAllElements('worksheet').first;
    XmlElement? drawingElement =
        worksheetElement.findElements('drawing').firstOrNull;

    if (drawingElement == null) {
      drawingElement = XmlElement(XmlName('drawing'), [
        XmlAttribute(XmlName('r:id'), 'rId1') // Assuming rId1 for simplicity
      ]);
      worksheetElement.children.add(drawingElement);
    }

    // Create drawing file for this sheet
    final drawingNumber = ++_drawingsCount;
    String drawingFileName = 'xl/drawings/drawing${drawingNumber}.xml';
    XmlDocument drawingXml = _createDrawingXml(sheetObject._drawing!);
    _excel._archive.addFile(ArchiveFile(
        drawingFileName,
        utf8.encode(drawingXml.toString()).length,
        utf8.encode(drawingXml.toString())));
    _excel._xmlFiles[drawingFileName] = drawingXml;

    // Add the drawing relationship to the sheet's relationship file
    _addSheetRelationship(_excel._xmlSheetId[sheetName]!.split("/").last,
        'drawing', _getFilePathWithoutXl(drawingFileName));

    _excel._xmlFiles['[Content_Types].xml']
        ?.findAllElements('Types')
        .first
        .children
        .add(XmlElement(
          XmlName('Override'),
          <XmlAttribute>[
            XmlAttribute(XmlName('ContentType'),
                'application/vnd.openxmlformats-officedocument.drawing+xml'),
            XmlAttribute(XmlName('PartName'), '/$drawingFileName'),
          ],
        ));

    // Add chart relationships
    for (var element in sheetObject._drawing!.allElements) {
      if (element is ChartElement) {
        String chartFileName =
            'xl/charts/chart${++_chartsCount}.xml'; // Assuming unique chart file names
        XmlDocument chartXml = _createChartXml(element.chart);
        _excel._archive.addFile(ArchiveFile(
            chartFileName,
            utf8.encode(chartXml.toString()).length,
            utf8.encode(chartXml.toString())));
        _excel._xmlFiles[chartFileName] = chartXml;

        _excel._xmlFiles['[Content_Types].xml']
            ?.findAllElements('Types')
            .first
            .children
            .add(XmlElement(
              XmlName('Override'),
              <XmlAttribute>[
                XmlAttribute(XmlName('ContentType'),
                    'application/vnd.openxmlformats-officedocument.drawingml.chart+xml'),
                XmlAttribute(XmlName('PartName'), '/$chartFileName'),
              ],
            ));

        // Add the chart relationship to the drawing's relationship file
        _addDrawingRelationship(
          drawingNumber,
          _getFilePathWithoutXl(chartFileName),
        );
      }
    }
  }

  /// Adds a relationship entry to the drawing's relationship file.
  void _addDrawingRelationship(int drawingNumber, String target) {
    String relFileName = 'xl/drawings/_rels/drawing${drawingNumber}.xml.rels';
    XmlDocument? relsFile = _excel._xmlFiles[relFileName];

    if (relsFile == null) {
      relsFile = XmlDocument([
        XmlElement(XmlName('Relationships'), [
          XmlAttribute(XmlName('xmlns'),
              'http://schemas.openxmlformats.org/package/2006/relationships')
        ], [])
      ]);
    }

    XmlElement relationships = relsFile.rootElement;

    relationships.children.add(XmlElement(
      XmlName('Relationship'),
      [
        XmlAttribute(XmlName('Id'), 'rId1'),
        XmlAttribute(XmlName('Type'),
            'http://schemas.openxmlformats.org/officeDocument/2006/relationships/chart'),
        XmlAttribute(XmlName('Target'), '../$target'),
      ],
    ));

    // Update archive files with the new relationship
    _excel._archive.addFile(ArchiveFile(
        relFileName,
        utf8.encode(relsFile.toString()).length,
        utf8.encode(relsFile.toString())));
    _excel._xmlFiles[relFileName] = relsFile;
  }

  /// Creates the XML for a drawing containing charts.
  XmlDocument _createDrawingXml(Drawing drawing) {
    XmlBuilder builder = XmlBuilder();
    builder.element('xdr:wsDr', nest: () {
      builder.attribute('xmlns:xdr',
          'http://schemas.openxmlformats.org/drawingml/2006/spreadsheetDrawing');
      builder.attribute(
          'xmlns:a', 'http://schemas.openxmlformats.org/drawingml/2006/main');
      builder.attribute('xmlns:r',
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships');
      builder.attribute(
          'xmlns:c', 'http://schemas.openxmlformats.org/drawingml/2006/chart');

      for (var element in drawing.allElements) {
        if (element is ChartElement) {
          _buildChartXml(builder, element);
        }
        // Other drawing elements can be added here if needed
      }
    });

    return builder.buildDocument();
  }

  /// Builds the XML for a chart element within a drawing.
  void _buildChartXml(XmlBuilder builder, ChartElement chartElement) {
    builder.element('xdr:oneCellAnchor', nest: () {
      builder.element('xdr:from', nest: () {
        builder.element('xdr:col', nest: chartElement.x);
        builder.element('xdr:colOff', nest: '485775');
        builder.element('xdr:row', nest: chartElement.y);
        builder.element('xdr:rowOff', nest: '171450');
      });
      builder.element('xdr:ext', attributes: {
        'cx': '10334625',
        'cy': '6400800',
      });
      builder.element('xdr:graphicFrame', nest: () {
        builder.attribute('macro', '');

        builder.element('xdr:nvGraphicFramePr', nest: () {
          builder.element('xdr:cNvPr', attributes: {
            'id': '2', // Assuming id 2
            'name': chartElement.name,
          });
          builder.element('xdr:cNvGraphicFramePr');
        });

        builder.element('xdr:xfrm', nest: () {
          builder.element('a:off', attributes: {'x': '0', 'y': '0'});
          builder.element('a:ext', attributes: {'cx': '0', 'cy': '0'});
        });

        builder.element('a:graphic', nest: () {
          builder.element('a:graphicData', attributes: {
            'uri': 'http://schemas.openxmlformats.org/drawingml/2006/chart'
          }, nest: () {
            builder.element('c:chart', attributes: {
              'r:id': 'rId1' // Assuming rId1 for the chart relationship
            });
          });
        });
      });

      builder.element('xdr:clientData');
    });
  }

  XmlDocument _createChartXml(Chart chart) {
    final builder = XmlBuilder();

    // Root element 'c:chartSpace' with namespaces
    builder.element('c:chartSpace', nest: () {
      builder.attribute(
          'xmlns:c', 'http://schemas.openxmlformats.org/drawingml/2006/chart');
      builder.attribute(
          'xmlns:a', 'http://schemas.openxmlformats.org/drawingml/2006/main');
      builder.attribute('xmlns:r',
          'http://schemas.openxmlformats.org/officeDocument/2006/relationships');

      // Chart element
      builder.element('c:chart', nest: () {
        // Chart Title
        builder.element('c:title', nest: () {
          builder.element('c:tx', nest: () {
            builder.element('c:rich', nest: () {
              builder.element('a:bodyPr');
              builder.element('a:lstStyle');
              builder.element('a:p', nest: () {
                builder.element('a:r', nest: () {
                  builder.element('a:rPr', nest: () {
                    builder.element('a:solidFill', nest: () {
                      builder.element('a:srgbClr', attributes: {
                        'val': '757575',
                      });
                    });
                    builder.element('a:latin', nest: () {
                      builder.attribute('typeface', '+mn-lt');
                    });
                  });
                  builder.element('a:t', nest: chart.title);
                });
              });
            });
          });
          builder.element('c:overlay', nest: () {
            builder.attribute('val', '0');
          });
        });

        // Plot Area
        builder.element('c:plotArea', nest: () {
          switch (chart.chartType) {
            case ChartType.columnChart:
              _buildColumnChart(builder, chart);
              break;
            case ChartType.lineChart:
              _buildLineChart(builder, chart);
              break;
            case ChartType.barChart:
              _buildBarChart(builder, chart);
              break;
            case ChartType.pieChart:
              _buildPieChart(builder, chart);
              break;
            case ChartType.scatterChart:
              _buildScatterChart(builder, chart);
              break;
            case ChartType.areaChart:
              _buildAreaChart(builder, chart);
              break;
            case ChartType.doughnutChart:
              _buildDoughnutChart(builder, chart);
              break;
          }
        });

        if (chart.chartType == ChartType.pieChart ||
            chart.chartType == ChartType.doughnutChart) {
          _buildLegend(builder);
        }
      });
    });

    // Build the final XML document
    return builder.buildDocument();
  }

  void _buildLegend(XmlBuilder builder) {
    builder.element('c:legend', nest: () {
      builder.element('c:legendPos', nest: () {
        builder.attribute('val', 'r');
      });
      builder.element('c:layout');
      builder.element('c:overlay', nest: () {
        builder.attribute('val', '0');
      });
      builder.element('c:txPr', nest: () {
        builder.element('a:bodyPr');
        builder.element('a:lstStyle');
        builder.element('a:p', nest: () {
          builder.element('a:pPr', attributes: {'lvl': '0'}, nest: () {
            builder.element('a:defRPr', attributes: {'b': '0'}, nest: () {
              builder.element('a:solidFill', nest: () {
                builder.element('a:srgbClr', attributes: {
                  'val': '757575',
                });
              });
              builder.element('a:latin', nest: () {
                builder.attribute('typeface', '+mn-lt');
              });
            });
          });
        });
      });
    });
  }

// Helper method to build chart series XML dynamically
  void _buildBarChart(XmlBuilder builder, Chart chart) {
    _addXmlStringToBuilder(
      builder,
      _getBarChartXmlString(chart, horizontal: true),
    );
  }

  void _buildAreaChart(XmlBuilder builder, Chart chart) {
    _addXmlStringToBuilder(
      builder,
      _getLineChartXmlString(chart, filled: true),
    );
  }

// Builds Column Chart XML
  void _buildColumnChart(XmlBuilder builder, Chart chart) {
    _addXmlStringToBuilder(
      builder,
      _getBarChartXmlString(chart, horizontal: false),
    );
  }

// Builds Line Chart XML
  void _buildLineChart(XmlBuilder builder, Chart chart) {
    _addXmlStringToBuilder(builder, _getLineChartXmlString(chart));
  }

// Builds Pie Chart XML
  void _buildPieChart(XmlBuilder builder, Chart chart) {
    _addXmlStringToBuilder(builder, _getPieChartXmlString(chart));
  }

// Builds Scatter Chart XML
  void _buildScatterChart(XmlBuilder builder, Chart chart) {
    _addXmlStringToBuilder(builder, _getScatterChartXmlString(chart));
  }

// Builds Doughnut Chart XML
  void _buildDoughnutChart(XmlBuilder builder, Chart chart) {
    _addXmlStringToBuilder(
      builder,
      _getPieChartXmlString(chart, filled: false),
    );
  }

  /// Adds a relationship entry to the sheet's relationship file.
  void _addSheetRelationship(String sheetName, String type, String target) {
    String relFileName = 'xl/worksheets/_rels/${sheetName}.rels';
    XmlDocument? relsFile = _excel._xmlFiles[relFileName];

    if (relsFile == null) {
      relsFile = XmlDocument([
        XmlElement(XmlName('Relationships'), [
          XmlAttribute(XmlName('xmlns'),
              'http://schemas.openxmlformats.org/package/2006/relationships')
        ], [])
      ]);
    }

    XmlElement relationships = relsFile.rootElement;

    relationships.children.add(XmlElement(
      XmlName('Relationship'),
      [
        XmlAttribute(XmlName('Id'), 'rId${relationships.children.length + 1}'),
        XmlAttribute(XmlName('Type'),
            'http://schemas.openxmlformats.org/officeDocument/2006/relationships/$type'),
        XmlAttribute(XmlName('Target'), '../$target'),
      ],
    ));

    // Update archive files with the new relationship
    _excel._archive.addFile(ArchiveFile(
        relFileName,
        utf8.encode(relsFile.toString()).length,
        utf8.encode(relsFile.toString())));
    _excel._xmlFiles[relFileName] = relsFile;
  }

  // slow implementation
/*   XmlElement _updateCell(String sheet, XmlElement node, int columnIndex,
      int rowIndex, CellValue? value) {
    XmlElement cell;
    var cells = _findCells(node);

    var currentIndex = 0; // cells could be empty
    for (var currentCell in cells) {
      currentIndex = _getCellNumber(currentCell);
      if (currentIndex >= columnIndex) {
        cell = currentCell;
        break;
      }
    }

    if (cell == null || currentIndex != columnIndex) {
      cell = _insertCell(sheet, node, cell, columnIndex, rowIndex, value);
    } else {
      cell = _replaceCell(sheet, node, cell, columnIndex, rowIndex, value);
    }

    return cell;
  } */
  XmlElement _updateCell(String sheet, XmlElement row, int columnIndex,
      int rowIndex, CellValue? value, NumFormat? numberFormat) {
    var cell = _createCell(sheet, columnIndex, rowIndex, value, numberFormat);
    row.children.add(cell);
    return cell;
  }

  _BorderSet _createBorderSetFromCellStyle(CellStyle cellStyle) => _BorderSet(
        leftBorder: cellStyle.leftBorder,
        rightBorder: cellStyle.rightBorder,
        topBorder: cellStyle.topBorder,
        bottomBorder: cellStyle.bottomBorder,
        diagonalBorder: cellStyle.diagonalBorder,
        diagonalBorderUp: cellStyle.diagonalBorderUp,
        diagonalBorderDown: cellStyle.diagonalBorderDown,
      );
}
