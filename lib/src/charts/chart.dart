part of excel;

class Chart {
  String _title = "";
  ChartType _chartType = ChartType.columnChart;
  ChartSeries _series;

  Sheet? _sheet;
  Sheet? get sheet => _sheet;

  Chart._({
    String? title,
    ChartType? chartType,
    required ChartSeries series,
  }) : _series = series {
    if (title != null) {
      _title = title;
    }
    if (chartType != null) {
      _chartType = chartType;
    }
  }

  Chart._clone(Chart oldChart)
      : this._(
          title: oldChart._title,
          chartType: oldChart._chartType,
          series: oldChart._series,
        );

  Chart.create({
    String? title,
    ChartType? chartType,
    required ChartSeries series,
  }) : _series = series {
    if (title != null) {
      _title = title;
    }
    if (chartType != null) {
      _chartType = chartType;
    }
  }

  void _setSheet(Sheet sheet) {
    _sheet = sheet;
  }

  /// Updates the chart's title.
  void updateTitle(String title) {
    _title = title;
  }

  /// Updates the chart's type.
  void updateChartType(ChartType chartType) {
    _chartType = chartType;
  }

  /// Retrieves the chart's title.
  String get title => _title;

  /// Retrieves the chart's type.
  ChartType get chartType => _chartType;

  // Scatter_Chart!$C$2:$C$7
  String? get seriesXRange {
    if (_series.xRange == null) {
      return null;
    }
    return "${_sheet!.sheetName}!${_series.xRange!.chartString()}";
  }

  // Scatter_Chart!$B$2:$B$7
  String get seriesYRange {
    return "${_sheet!.sheetName}!${_series.yRange.chartString()}";
  }
}

class ChartSeries {
  final String name; // Series name
  final Range?
      xRange; // X values (numeric or category) - can be null for pie/doughnut charts
  final Range yRange; // Y values (numeric)
  final String?
      categoryRange; // Category values for Pie, Doughnut charts - can be null for others
  final Color color; // Optional: Series color

  ChartSeries({
    required this.name,
    this.xRange,
    required this.yRange,
    this.categoryRange,
    this.color = Color.blue,
  });
}

enum ChartType {
  columnChart,
  lineChart,
  barChart,
  pieChart,
  scatterChart,
  areaChart,
  doughnutChart,
}
