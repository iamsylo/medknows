import 'package:flutter/material.dart';

class MedicineDetailsCard extends StatelessWidget {
  final String image;
  final String name;
  final String genericName;
  final String description;
  final List<String> categories;
  final String dosage;
  final String directionsOfUse;
  final String administration;
  final String contraindication;
  final VoidCallback onClose;

  const MedicineDetailsCard({
    Key? key,
    required this.image,
    required this.name,
    required this.genericName,
    required this.description,
    required this.categories,
    required this.dosage,
    required this.directionsOfUse,
    required this.administration,
    required this.contraindication,
    required this.onClose,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Darken the background
        Container(
          key: key, // Add this line
          color: Colors.black.withOpacity(0.5),
        ),
        Center(
          child: Container(
            width: 350, // Adjusted width for the card
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: SingleChildScrollView( // Make the card scrollable
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Align(
                        alignment: Alignment.topRight,
                        child: IconButton(
                          icon: Icon(Icons.close),
                          onPressed: onClose,
                        ),
                      ),
                      Image.asset(
                        image,
                        height: 150,
                        fit: BoxFit.contain,
                      ),
                      SizedBox(height: 16),
                      Text(
                        name,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        genericName,
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                        textAlign: TextAlign.center, // Add this line
                      ),
                      SizedBox(height: 16),
                      Container(
                        width: double.infinity, // Ensure the container takes the full width
                        padding: const EdgeInsets.all(16.0), // Adjusted padding
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16), // Softer edges
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Description',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8), // Adjusted spacing
                            Text(
                              description,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Dosage',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8), // Adjusted spacing
                            Text(
                              dosage,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Directions of Use',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8), // Adjusted spacing
                            Text(
                              directionsOfUse,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Administration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8), // Adjusted spacing
                            Text(
                              administration,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Contraindication',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8), // Adjusted spacing
                            Text(
                              contraindication,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.black,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 8), // Adjusted spacing
                            Wrap(
                              spacing: 8.0,
                              runSpacing: 4.0,
                                children: categories.map((category) {
                                return Chip(
                                  label: Text(
                                  category,
                                  style: TextStyle(fontSize: 10),
                                  ),
                                  backgroundColor: Colors.grey[200],
                                  labelStyle: TextStyle(color: Colors.black),
                                  shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                  ),
                                );
                                }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}