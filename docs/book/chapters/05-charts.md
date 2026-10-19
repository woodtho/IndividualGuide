# Charts that remain useful downstream {#charts}

The Graph category contains ten task types. Each uses a table plus explicit variable mappings and can expose a data table, an interactive plot and a static ggplot image. The graph task is the producer; an Export or Report task is a consumer of the retained output you select.

Start with the question and the unit of observation. Category counts suggest bars, a numeric distribution suggests a histogram, paired numeric measurements suggest a scatter plot, and an ordered series suggests a line. A visually elaborate chart is not necessarily more informative than a simple one with correct units and a clear denominator.

## Shared mapping and output controls

X/Y choose variables, not fixed numbers. Group/colour/fill supplies series or categories where supported. Size supplies a numeric bubble mapping where applied. Facet splits a display into panels. Blank optional mappings are different from selecting an actual column containing missing values.

The shared parameter schema contains fields for several chart/statistical families. A field in the parameter appendix does not imply every task shows or uses that field. For example, the ordinary Scatter Plot panel shares a Size selection, but its current plotting implementation does not apply a point-size mapping; use **Bubble Plot** when size must encode a third variable.

Choose retained outputs deliberately. The table and interactive plot are commonly enabled by default; the static image is generally optional. A static image output is a plot value that can be rendered to PNG/SVG/PDF, not a pre-existing file whose DPI is fixed forever. Name each enabled output so a Report/Export task can select it without confusing it with the input table.

Graph result tables need careful interpretation. Count bars, pies and histograms return computed counts/bins. Many other graph tasks retain at most the first **1,000 input rows** as their primary data output, while their plotted layer can use the full input. The scatter-matrix display itself also uses a first-1,000-row cap. Do not use a graph's retained table as a presumed full-data substitute for the original analytical table.

## Styling, dimensions and export

Plot styling includes title, subtitle, X/Y labels, caption, theme, palette, legend placement and grid display. Themes include Clean, Publication, Minimal, Classic, Light and Dark. Palettes include Individual Guide, Okabe-Ito, Tableau, Viridis and Grey. A numeric group can use a continuous scale; a categorical group uses discrete colours. Repeated palette colours can be necessary when categories exceed available colours, so avoid interpreting colour alone as a unique identifier in a large legend.

Opacity controls help with overplotting but do not solve every density problem. Line width, bin count, bar opacity and point opacity are enabled where relevant. Default graph dimensions in the current constructors are eight by four; renderer minimums constrain very small choices. Export has its own dimensions, units and DPI, so check the final file rather than assuming its size matches an on-screen card.

Interactive widgets support hover behavior where interactive layers supply tooltips. Wrapping a noninteractive statistical layer in a widget does not create a detailed tooltip for every component. Static files have no live hover behavior. Interactive widgets export to HTML or SVG; raster image formats belong to the static plot output. The output chapter lists the exact format families.

The example libraries retain static plot values for portable saved projects. Cached interactive widgets can contain machine-specific font resources. Re-enable the interactive plot output and rerun locally when you want its live interaction. This is not a loss of the underlying observations or plot specification.

## Bar Chart {#task-bar_chart}

Choose a category/X field. With Y blank, the chart counts rows by category, with optional fill grouping. The retained data table contains category counts. This is appropriate for questions such as how many observations belong to each species or how many orders fall into each status.

With a numeric Y field, the task uses value bars rather than silently taking a group mean. If several observations share a category, the geometry can stack/overlap according to its configured grouping; compute a deliberate summary first when the question is mean or total by group. Do not label the chart “average” without a matching aggregation task.

Flip makes a horizontal layout. Use readable category labels and a scale suitable for counts/values. The categorical chart gallery counts Iris species, giving three bars of 50. Its balance is easy to verify against One-Way Frequencies and makes a useful first chart test.

## Bar-Line Chart {#task-bar_line_chart}

Choose X and numeric Y for a combined bar/line display. Without a secondary Y, the line follows the selected Y values over X. Grouping can define line series. An optional secondary numeric Y is drawn through a scale transformation with a labelled secondary axis.

Use this when two related summaries share a meaningful ordered X, and prepare one row per intended X/group first. Connecting raw duplicate X values can give a picture unlike the intended monthly trend. The task does not automatically decide whether repeated records should be summed or averaged.

The Nottingham temperature example first calculates annual means and ranges, then plots the mean as bars and range as a secondary series. Its axis label explicitly states that the second measure is an annual range in degrees Fahrenheit. Dual axes can make unrelated curves appear to align; explain the two units and transformation rather than presenting visual agreement as evidence of a relationship.

## Box Plot {#task-box_plot}

Choose a category X and numeric Y, with optional fill group and horizontal layout. Numeric X values are treated as categories in this task so a dose or cylinder-count grouping does not accidentally collapse into one continuous-position box.

Boxes summarize distributions within categories using ggplot's box-plot conventions. A displayed outlying point is not automatically a bad record, and a box overlap is not a formal test of a group difference. Small groups and unequal sample sizes deserve explicit counts beside the figure.

The categorical gallery plots petal length by species. Inspect the underlying `flowers` table and its group summaries when a box looks unexpected. If you need the numerical quartile values as a retained table, use Summary Statistics/Summary Tables or a Script; the graph's primary data output should not be mistaken for a dedicated table of box boundaries.

## Bubble Plot {#task-bubble_plot}

Choose numeric X/Y and a numeric size variable. An optional colour group adds a categorical or continuous distinction where appropriate. The task uses interactive point layers with mapped values available to tooltips.

Use a size field with an interpretable nonnegative magnitude. A third variable with mixed signs or poorly understood units is difficult to communicate through area. Check how size changes perceptually and include a useful size legend. More dimensions do not compensate for a missing analytical question.

The numeric gallery maps sepal length against petal length, sizes by petal width and colours by species. Compare it with the ordinary scatter plot to judge whether size adds useful information or simply clutter. For dense data, adjust opacity or use a density display; very large bubbles can hide smaller observations completely.

## Contour Plot {#task-contour_plot}

Contour Plot estimates a two-dimensional density from numeric X/Y and draws filled density contours. It helps reveal concentration when a scatter plot contains too many overlapping points. It is not a contour map of a separately supplied Z measurement and does not accept arbitrary spatial elevation as an implied third field.

The implementation delegates density estimation/contouring to ggplot's statistical layer. It does not expose every bandwidth parameter through the task UI. Sparse, degenerate or near-constant variables can make the estimate uninformative or fail. Inspect the scatter plot and original ranges first.

The numeric gallery uses Iris sepal and petal lengths. Contour bands describe the distribution of those observations; they are not confidence regions for a regression coefficient or proof of discrete clusters. If you need category-specific densities or a custom bandwidth, use an explicit Script/ggplot specification and retain the resulting plot.

## Histogram {#task-histogram_graph}

Choose a numeric X, bin count and optional fill group. The retained table contains bin edges, midpoints, counts and densities, with group/panel information where applicable. This is one of the graph tasks whose result table is a computed plotting summary rather than a raw-data subset.

The optional density overlay changes the histogram's vertical mapping to density so the continuous curve uses a compatible scale. A density overlay needs at least two finite observations. Changing the bin count can reveal or conceal structure; compare a few reasonable choices and keep units visible on X.

The numeric gallery uses 15 bins for sepal length. The sum of bin counts is a useful check, while missing/nonfinite handling and grouped panels need attention when comparing to a raw row count. For a formal numeric summary or missingness audit, use the Describe tasks as well. A histogram alone does not tell you whether a value is missing because it was absent, filtered or converted unsuccessfully.

## Line Plot {#task-line_plot}

Choose an ordered numeric or date X and numeric Y. Optional grouping defines separate series; an optional secondary Y uses the same secondary-axis mechanism as Bar-Line. The line geometry connects observations according to X within its grouping conventions.

Prepare chronological order and a meaningful time spacing. Repeated X values can create vertical segments; absent months do not become observed zeroes. A date axis is not a substitute for deciding how missing periods should be represented. Keep multiple series identified with a proper group field so observations from different series are not accidentally connected.

The Nottingham example constructs a Date for each monthly temperature and draws the full ordered series. It is a visualization, not an ARIMA model or a forecast. Use the forecasting task when you need an estimated future distribution, and preserve the difference between observed and predicted periods in a report.

## Pie Chart {#task-pie_chart}

Choose a categorical field. The task counts observations, retains the count table and draws category shares. A Donut option changes the presentation. It does not map an arbitrary numeric Y into slice values; create the appropriate supported data representation or a custom plot if weighted shares are required.

Missing values are counted when present in the category table. Check the denominator and make category names readable. A large number of small slices is difficult to compare; a bar chart is often easier for precise category comparisons.

The categorical gallery's three Iris species give equal thirds. That is a useful check of the count-based behavior. If your input already has one row per category with a count column, a count-based pie would count those rows rather than silently use that count column as weights. This distinction is easy to miss when the table happens to look like a plotting summary.

## Scatter Plot {#task-scatter_plot}

Choose X and numeric Y, with optional colour grouping and faceting. Use it to inspect paired measurements and identify ranges, unusual observations or possible relationships before modelling. Interactive point tooltips expose mapped fields.

The current ordinary scatter implementation does not apply the shared Size field to its points. Use Bubble Plot for an actual third-variable size encoding. A numeric group can imply a continuous colour scale; convert a numeric category to factor when it is genuinely categorical and the desired interpretation is discrete.

The Iris and fuel-economy projects show species grouping and weight/mpg association. A scatter pattern does not identify causality. Overplotting can hide repeated observations, so consider opacity, grouping or density displays. Remember that the retained graph data table can be capped at 1,000 rows while the plotted data source is larger; use the original table for downstream full-data calculations.

## Scatter Plot Matrix {#task-scatter_matrix}

Select at least two numeric columns. Choose **Pairwise scatterplots** or **Distributions**. Pairwise mode creates a grid of variable pairs; distribution mode creates faceted histograms. The current default constructor chooses pairwise mode, even though older help text may describe only the histogram view.

The display uses the first **1,000 rows**, not a random sample. This cap keeps large grids manageable but can bias an exploratory impression when row order contains time, group or quality structure. If you need a representative subset, create a seeded sample before the matrix and describe it in the caption.

The numeric gallery uses the four Iris measurements, giving a manageable grid. Larger variable selections grow the pair grid rapidly and can become unreadable. Select a coherent subset, inspect missing/constant columns and compare any apparent patterns with full-data summaries. A correlation table is related but answers a different question from the shapes and outliers visible in a pair plot.

## A chart review routine

Check the input's observation count and classes. State what one plotted mark represents. Verify aggregation and denominators. Label units and any secondary axis. Inspect missingness, group membership and limits. Compare a plotted count/summary with an independent table. Then render the final exported file at its intended size and open it outside the app.

When adding a chart to a report, choose the static or interactive output deliberately. HTML can embed interaction; Word cannot reproduce a browser widget's behavior. A static figure with a clear caption is usually easier to carry across output formats. Retain the plotting specification in the task so a later correction is a rerun, not manual editing of a detached image.
