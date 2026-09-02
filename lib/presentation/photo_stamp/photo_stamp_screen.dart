import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../services/image_service/name_date_stamper.dart';
import '../result/result_screen.dart';
import '../widgets/gradient_button.dart';

class PhotoStampScreen extends StatefulWidget {
  final File initialImage;

  const PhotoStampScreen({
    super.key,
    required this.initialImage,
  });

  @override
  State<PhotoStampScreen> createState() => _PhotoStampScreenState();
}

class _PhotoStampScreenState extends State<PhotoStampScreen> {
  late TextEditingController _nameController;
  late TextEditingController _dateController;
  DateTime _selectedDate = DateTime.now();
  int _targetSizeKB = 48; // Under 50 KB for SSC / UPSC
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: 'YOUR NAME');
    _dateController = TextEditingController(
      text: DateFormat('dd/MM/yyyy').format(_selectedDate),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _handleStamp() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter candidate name')),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final options = PhotoStampOptions(
        sourcePath: widget.initialImage.path,
        candidateName: name,
        dateOfPhoto: _dateController.text.trim(),
        targetSizeKB: _targetSizeKB,
      );

      final result = await NameDateStamper.stampPhoto(options);

      if (!mounted) return;
      setState(() => _isProcessing = false);

      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ResultScreen(result: result),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isProcessing = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating stamped photo: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Name & Date on Photo'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            32 + MediaQuery.paddingOf(context).bottom,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Live Simulation Preview Card
              Container(
                decoration: BoxDecoration(
                  color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  ),
                ),
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.bottomCenter,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            height: 220,
                            width: double.infinity,
                            color: isDark ? Colors.black26 : Colors.grey.shade100,
                            child: Image.file(
                              widget.initialImage,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        // Live Footer Overlay Simulation
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              top: BorderSide(color: Colors.grey, width: 1),
                            ),
                            borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _nameController.text.isEmpty
                                    ? 'CANDIDATE NAME'
                                    : _nameController.text.toUpperCase(),
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'DOP: ${_dateController.text}',
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Inputs Section
              Text(
                'Candidate Name (as per ID)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _nameController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  hintText: 'e.g. RAHUL SHARMA',
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 16),

              Text(
                'Date of Photo (DOP)',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _dateController,
                readOnly: true,
                onTap: _pickDate,
                decoration: InputDecoration(
                  suffixIcon: const Icon(Icons.calendar_today, size: 20),
                  filled: true,
                  fillColor: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // Target Size
              Text(
                'Target Size Preset',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                children: [48, 98, 190].map((size) {
                  final isSelected = _targetSizeKB == size;
                  return ChoiceChip(
                    label: Text(size == 48 ? '20-50 KB (SSC/Vyapam)' : '< ${size + 2} KB'),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                    onSelected: (sel) {
                      if (sel) setState(() => _targetSizeKB = size);
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 36),

              GradientButton(
                text: '🏷️ Create Stamped Photo',
                isLoading: _isProcessing,
                onPressed: _isProcessing ? null : _handleStamp,
              ),
              const SizedBox(height: 16),
              const SafeArea(
                top: false,
                child: SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
