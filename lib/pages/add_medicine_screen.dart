import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class AddMedicineScreen extends StatefulWidget {
  const AddMedicineScreen({Key? key}) : super(key: key);

  @override
  _AddMedicineScreenState createState() => _AddMedicineScreenState();
}

class _AddMedicineScreenState extends State<AddMedicineScreen> {
  final _formKey = GlobalKey<FormState>();
  File? _imageFile;
  final List<String> _categories = [];
  final List<String> _interactions = [];
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _genericNameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  final TextEditingController _directionsController = TextEditingController();
  final TextEditingController _administrationController = TextEditingController();
  final TextEditingController _contraindicationController = TextEditingController();
  final TextEditingController _ageRestrictionController = TextEditingController();
  final TextEditingController _activeIngredientController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  final TextEditingController _interactionController = TextEditingController();

  Future<void> _pickImage() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      setState(() {
        _imageFile = File(image.path);
      });
    }
  }

  void _addCategory() {
    if (_categoryController.text.isNotEmpty) {
      setState(() {
        _categories.add(_categoryController.text);
        _categoryController.clear();
      });
    }
  }

  void _addInteraction() {
    if (_interactionController.text.isNotEmpty) {
      setState(() {
        _interactions.add(_interactionController.text);
        _interactionController.clear();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Add Medicine',
          style: GoogleFonts.openSans(),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Image Upload
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _imageFile != null
                      ? Image.file(_imageFile!, fit: BoxFit.cover)
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.add_photo_alternate, size: 50),
                            Text('Upload Image'),
                          ],
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Basic Information
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Medicine Name*',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'This field is required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _genericNameController,
              decoration: const InputDecoration(
                labelText: 'Generic Name*',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'This field is required' : null,
            ),
            const SizedBox(height: 16),

            // Categories
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Add Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addCategory,
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: _categories
                  .map((category) => Chip(
                        label: Text(category),
                        onDeleted: () {
                          setState(() {
                            _categories.remove(category);
                          });
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // Detailed Information
            TextFormField(
              controller: _descriptionController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description*',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'This field is required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _dosageController,
              decoration: const InputDecoration(
                labelText: 'Dosage*',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'This field is required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _directionsController,
              maxLines: 2,
              decoration: const InputDecoration(
                labelText: 'Directions of Use*',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'This field is required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _administrationController,
              decoration: const InputDecoration(
                labelText: 'Administration*',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'This field is required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _contraindicationController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Contraindication*',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'This field is required' : null,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _ageRestrictionController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Age Restriction*',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'This field is required' : null,
            ),
            const SizedBox(height: 16),

            // Interactions
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _interactionController,
                    decoration: const InputDecoration(
                      labelText: 'Add Interaction',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  onPressed: _addInteraction,
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              children: _interactions
                  .map((interaction) => Chip(
                        label: Text(interaction),
                        onDeleted: () {
                          setState(() {
                            _interactions.remove(interaction);
                          });
                        },
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _activeIngredientController,
              decoration: const InputDecoration(
                labelText: 'Active Ingredient*',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'This field is required' : null,
            ),
            const SizedBox(height: 24),

            ElevatedButton(
              onPressed: () {
                if (_formKey.currentState?.validate() ?? false) {
                  // TODO: Implement medicine saving logic
                  // Create a map of the medicine data and save it
                }
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Save Medicine'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _genericNameController.dispose();
    _descriptionController.dispose();
    _dosageController.dispose();
    _directionsController.dispose();
    _administrationController.dispose();
    _contraindicationController.dispose();
    _ageRestrictionController.dispose();
    _activeIngredientController.dispose();
    _categoryController.dispose();
    _interactionController.dispose();
    super.dispose();
  }
}
