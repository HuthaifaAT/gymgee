import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:gymgee/models/workout.dart';
import 'package:gymgee/services/sharing_service.dart';
import 'package:gymgee/services/storage_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';


class ShareProgressScreen extends StatefulWidget {
  const ShareProgressScreen({Key? key}) : super(key: key);

  @override
  _ShareProgressScreenState createState() => _ShareProgressScreenState();
}

class _ShareProgressScreenState extends State<ShareProgressScreen> {
  final SharingService _sharingService = SharingService();
  late StorageService _storageService;

  DateTime _startDate = DateTime.now().subtract(Duration(days: 7));
  DateTime _endDate = DateTime.now();

  bool _isLoading = true;
  List<Workout> _workouts = [];
  String? _generatedReport;
  bool _isGeneratingReport = false;

  final TextEditingController _phoneNumberController = TextEditingController();
  final TextEditingController _coachNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _storageService = Provider.of<StorageService>(context, listen: false);
    _loadWorkouts();
  }

  Future<void> _loadWorkouts() async {
    setState(() {
      _isLoading = true;
    });

    final workouts = await _storageService.getAllWorkouts();

    setState(() {
      _workouts = workouts;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Share Progress'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDateRangePicker(),
          SizedBox(height: 24),
          _buildCoachInfo(),
          SizedBox(height: 24),
          _buildGenerateReportButton(),
          SizedBox(height: 24),
          _generatedReport != null
              ? _buildReportPreview()
              : Container(),
          SizedBox(height: 24),
          _buildShareOptions(),
        ],
      ),
    );
  }

  Widget _buildDateRangePicker() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Date Range',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(true),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'Start Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('yyyy-MM-dd').format(_startDate)),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(false),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: 'End Date',
                        border: OutlineInputBorder(),
                      ),
                      child: Text(DateFormat('yyyy-MM-dd').format(_endDate)),
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildDateRangeButton('Last 7 Days', 7),
                _buildDateRangeButton('Last 14 Days', 14),
                _buildDateRangeButton('Last 30 Days', 30),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRangeButton(String label, int days) {
    return OutlinedButton(
      child: Text(label),
      onPressed: () {
        setState(() {
          _endDate = DateTime.now();
          _startDate = DateTime.now().subtract(Duration(days: days));
          _generatedReport = null;
        });
      },
    );
  }

  Widget _buildCoachInfo() {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Coach Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _coachNameController,
              decoration: InputDecoration(
                labelText: 'Coach Name',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
            ),
            SizedBox(height: 16),
            TextField(
              controller: _phoneNumberController,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: 'WhatsApp Number (optional)',
                hintText: '+1234567890',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenerateReportButton() {
    return Center(
      child: ElevatedButton.icon(
        icon: Icon(Icons.auto_awesome),
        label: Text('Generate Progress Report'),
        onPressed: _isGeneratingReport ? null : _generateReport,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildReportPreview() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Report Preview',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 8),
        Card(
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _generatedReport!.split('\n').take(3).join('\n'),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '${_generatedReport!.split('\n').length - 3} more lines...',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildShareOptions() {
    return _generatedReport != null
        ? Card(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Share With',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildShareButton(
                  icon: FontAwesomeIcons.squareWhatsapp,
                  label: 'WhatsApp',
                  color: Colors.green,
                  onPressed: () => _shareViaWhatsApp(),
                ),
                _buildShareButton(
                  icon: Icons.discord,
                  label: 'Discord',
                  color: Colors.indigo,
                  onPressed: () => _shareViaDiscord(),
                ),
                _buildShareButton(
                  icon: Icons.share,
                  label: 'Other',
                  color: Colors.blue,
                  onPressed: () => _shareViaOther(),
                ),
              ],
            ),
            SizedBox(height: 16),
            Center(
              child: OutlinedButton.icon(
                icon: Icon(Icons.file_download),
                label: Text('Export as JSON'),
                onPressed: _exportAsJson,
              ),
            ),
          ],
        ),
      ),
    )
        : Container();
  }

  Widget _buildShareButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: color,
          child: IconButton(
            icon: Icon(icon, color: Colors.white, size: 28),
            onPressed: onPressed,
          ),
        ),
        SizedBox(height: 8),
        Text(label),
      ],
    );
  }

  Future<void> _selectDate(bool isStartDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: isStartDate ? _startDate : _endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (pickedDate != null) {
      setState(() {
        if (isStartDate) {
          _startDate = pickedDate;
        } else {
          _endDate = pickedDate;
        }
        _generatedReport = null;
      });
    }
  }

  Future<void> _generateReport() async {
    setState(() {
      _isGeneratingReport = true;
    });

    try {
      // Filter workouts in the selected date range
      final filteredWorkouts = _workouts
          .where((w) => w.lastPerformed != null &&
          w.lastPerformed!.isAfter(_startDate) &&
          w.lastPerformed!.isBefore(_endDate.add(Duration(days: 1))))
          .toList();

      final report = await _sharingService.generateWeeklyReport(filteredWorkouts, _startDate);

      setState(() {
        _generatedReport = report;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating report: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() {
        _isGeneratingReport = false;
      });
    }
  }

  Future<void> _shareViaWhatsApp() async {
    if (_generatedReport == null) return;

    final phoneNumber = _phoneNumberController.text.trim();

    final success = await _sharingService.shareViaWhatsApp(
      _generatedReport!,
      phoneNumber: phoneNumber,
    );

    _showShareResult(success, 'WhatsApp');
  }

  Future<void> _shareViaDiscord() async {
    if (_generatedReport == null) return;

    final success = await _sharingService.shareViaDiscord(_generatedReport!);

    _showShareResult(success, 'Discord');
  }

  Future<void> _shareViaOther() async {
    if (_generatedReport == null) return;

    final success = await _sharingService.shareViaAny(_generatedReport!);

    _showShareResult(success, 'other apps');
  }

  Future<void> _exportAsJson() async {
    // Filter workouts in the selected date range
    final filteredWorkouts = _workouts
        .where((w) => w.lastPerformed != null &&
        w.lastPerformed!.isAfter(_startDate) &&
        w.lastPerformed!.isBefore(_endDate.add(Duration(days: 1))))
        .toList();

    final success = await _sharingService.exportWorkoutsAsJson(filteredWorkouts);

    _showShareResult(success, 'JSON export');
  }

  void _showShareResult(bool success, String method) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Successfully shared via $method'
              : 'Failed to share via $method',
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }
}
