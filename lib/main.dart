import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

void main() {
  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const PdfTabView(),
      theme: Theme.of(context).copyWith(
        iconButtonTheme: IconButtonThemeData(
          style: ButtonStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A tab view to display multiple PDF files
class PdfTabView extends StatefulWidget {
  const PdfTabView({super.key});

  @override
  State<PdfTabView> createState() => _PdfTabViewState();
}

class _PdfTabViewState extends State<PdfTabView> with TickerProviderStateMixin {
  late TabController _tabController;
  late final List<PdfFile> _openedFiles;

  @override
  void initState() {
    // Initialize the list of opened PDF files
    _openedFiles = <PdfFile>[];
    // Initialize the TabController
    _tabController = TabController(length: _openedFiles.length, vsync: this);
    super.initState();
  }

  @override
  void dispose() {
    _openedFiles.clear();
    // Dispose the TabController
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            // Add a button to open a new PDF file
            child: OutlinedButton(
              onPressed: _addNewTab,
              style: ButtonStyle(
                shape: WidgetStateProperty.all(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
              child: const Row(
                children: [
                  Icon(Icons.add, size: 20),
                  SizedBox(width: 8),
                  Padding(
                    padding: EdgeInsets.only(bottom: 1.5, right: 4),
                    child: Text('Open PDF'),
                  ),
                ],
              ),
            ),
          ),
        ],

        /// Add the tab bar with close button for each tab
        bottom: TabBar(
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          controller: _tabController,
          splashFactory: NoSplash.splashFactory,
          indicator: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(5),
              topRight: Radius.circular(5),
            ),
          ),
          labelStyle: TabBarTheme.of(context).labelStyle ??
              Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
          indicatorSize: TabBarIndicatorSize.tab,
          tabs: _openedFiles.map((PdfFile file) {
            return Tab(
              child: Row(
                children: [
                  Text(file.name),
                  SizedBox.fromSize(
                    size: const Size.square(24),
                    child: IconButton(
                      onPressed: () {
                        _removeTab(_tabController.index);
                      },
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
      // Display the PDF file in the selected tab
      body: TabBarView(
        physics: const NeverScrollableScrollPhysics(),
        controller: _tabController,
        children: _openedFiles.map((PdfFile file) {
          return PdfView(
            key: file.key,
            bytes: file.bytes,
          );
        }).toList(),
      ),
    );
  }

  void _removeTab(int index) {
    // Remove the PDF file from the list of opened files
    _openedFiles.removeAt(index);
    // If the current tab is closed, go to the previous tab
    int gotoIndex = _tabController.index == index
        ? _tabController.index - 1
        : _tabController.index;

    // Dispose the old TabController
    _tabController.dispose();
    if (_openedFiles.isNotEmpty) {
      gotoIndex = gotoIndex.clamp(0, _openedFiles.length - 1);
    } else {
      gotoIndex = 0;
    }
    setState(() {
      // Update the TabController
      _tabController = TabController(
        length: _openedFiles.length,
        vsync: this,
        initialIndex: gotoIndex,
      );
    });
  }

  /// Add a new tab to open a PDF file
  Future<void> _addNewTab() async {
    // Pick a PDF file
    final FilePickerResult? filePickerResult =
        await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    /// Check if the file is picked
    if (filePickerResult == null) {
      return;
    }

    String fileName = filePickerResult.files.single.name;
    // remove file extension
    fileName = fileName.substring(0, fileName.length - 4);

    Uint8List? bytes;
    if (kIsWeb) {
      // Read the bytes of the file picked in web platform
      bytes = filePickerResult.files.single.bytes;
    } else {
      final String? filePath = filePickerResult.files.single.path;
      if (filePath == null) {
        return;
      }
      // Get the file path and read the bytes of the file picked in mobile and desktop platforms
      final File file = File(filePath);
      bytes = await file.readAsBytes();
    }

    // Check if the file is null
    if (bytes == null) {
      return;
    }

    // Check if the file is already opened by comparing the file name
    int index = _openedFiles.indexWhere((element) => element.name == fileName);

    // Check if the file is already opened by comparing the bytes
    if (index != -1 && listEquals(_openedFiles[index].bytes, bytes)) {
      _tabController.animateTo(index);
      return;
    }

    setState(() {
      // Add the new PDF file to the list of opened files
      _openedFiles.add(PdfFile(fileName, bytes!, UniqueKey()));
      // Update the TabController
      _tabController = TabController(
        length: _openedFiles.length,
        vsync: this,
        initialIndex: _openedFiles.length - 1,
      );
    });
  }
}

/// A widget to display the PDF file
class PdfView extends StatefulWidget {
  const PdfView({super.key, required this.bytes});

  /// The PDF file as bytes
  final Uint8List bytes;

  @override
  State<PdfView> createState() => _PdfViewState();
}

class _PdfViewState extends State<PdfView>
    with AutomaticKeepAliveClientMixin<PdfView> {
  late final PdfViewerController _pdfViewerController;
  final GlobalKey<SfPdfViewerState> _pdfViewerKey = GlobalKey();

  @override
  void initState() {
    // Initialize the PdfViewerController
    _pdfViewerController = PdfViewerController();
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
    // Dispose the PdfViewerController
    _pdfViewerController.dispose();
  }

  /// Keep the state alive when switching between tabs
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      // Add the app bar with navigation and zoom controls
      appBar: AppBar(
        actions: [
          const Spacer(flex: 16),
          IconButton(
            onPressed: _pdfViewerController.previousPage,
            icon: const Icon(Icons.keyboard_arrow_up),
          ),
          IconButton(
            onPressed: _pdfViewerController.nextPage,
            icon: const Icon(Icons.keyboard_arrow_down),
          ),
          const Spacer(flex: 1),
          PageNumber(pdfViewerController: _pdfViewerController),
          const Spacer(flex: 1),
          IconButton(
            onPressed: () => _pdfViewerController.zoomLevel -= 0.5,
            icon: const Icon(Icons.zoom_out),
          ),
          IconButton(
            onPressed: () => _pdfViewerController.zoomLevel += 0.5,
            icon: const Icon(Icons.zoom_in),
          ),
          const Spacer(flex: 16),
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: IconButton(
              onPressed: () => _pdfViewerKey.currentState?.openBookmarkView(),
              icon: const Icon(Icons.bookmark_border),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1.0),
          child: Container(
            color: Theme.of(context).colorScheme.outlineVariant,
            height: 1.0,
          ),
        ),
      ),
      // Display the PDF file using SfPdfViewer
      body: SfPdfViewer.memory(
        widget.bytes,
        key: _pdfViewerKey,
        controller: _pdfViewerController,
      ),
    );
  }
}

// Model class to store the PDF file details
class PdfFile {
  final String name;
  final Uint8List bytes;
  final Key key;

  PdfFile(this.name, this.bytes, this.key);
}

// Widget to display the current page number and total page count
class PageNumber extends StatefulWidget {
  const PageNumber({super.key, required this.pdfViewerController});

  final PdfViewerController pdfViewerController;

  @override
  State<PageNumber> createState() => _PageNumberState();
}

class _PageNumberState extends State<PageNumber> {
  late final TextEditingController _textEditingController;
  late final FocusNode _focusNode;

  @override
  void initState() {
    widget.pdfViewerController.addListener(_update);
    _textEditingController = TextEditingController(
      text: widget.pdfViewerController.pageNumber.toString(),
    );
    _focusNode = FocusNode();
    super.initState();
  }

  @override
  void dispose() {
    widget.pdfViewerController.removeListener(_update);
    _textEditingController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// Update the page number in the text field
  void _update() {
    Future<void>.delayed(Duration.zero, () {
      if (mounted) {
        _textEditingController.text =
            widget.pdfViewerController.pageNumber.toString();
        setState(() {});
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Row(
        children: [
          SizedBox(
            width: kToolbarHeight,
            height: kToolbarHeight / 1.5,
            child: TextField(
              controller: _textEditingController,
              enableInteractiveSelection: false,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                contentPadding: const EdgeInsets.only(bottom: 4),
                border: const OutlineInputBorder(),
                enabledBorder: const OutlineInputBorder(),
                focusedBorder: OutlineInputBorder(
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              focusNode: _focusNode,
              onEditingComplete: _changePage,
              onTapOutside: (_) => _focusNode.unfocus(),
            ),
          ),
          Text(
            ' / ${widget.pdfViewerController.pageCount}',
          ),
        ],
      ),
    );
  }

  /// Jump to the page number entered in the text field
  void _changePage() {
    // Check if the entered page number is valid
    final int? pageNumber = int.tryParse(_textEditingController.text);
    if (pageNumber != null) {
      if (pageNumber > 0 &&
          pageNumber <= widget.pdfViewerController.pageCount) {
        // Jump to the entered page number
        widget.pdfViewerController
            .jumpToPage(int.parse(_textEditingController.text));
        _focusNode.unfocus();
        return;
      }
    }
    // Reset the text field to the current page number
    _textEditingController.text =
        widget.pdfViewerController.pageNumber.toString();
    _focusNode.unfocus();
  }
}
