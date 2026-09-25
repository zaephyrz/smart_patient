import 'package:flutter_dotenv/flutter_dotenv.dart';

class Environment {
  static String get backendUrl => dotenv.env['BACKEND_URL'] ?? 'http://localhost:8000';
  static String get apiVersion => dotenv.env['API_VERSION'] ?? '/api/v1';
  
  static String get loginEndpoint => 
      '$backendUrl$apiVersion${dotenv.env['LOGIN_ENDPOINT'] ?? '/auth/login'}';
  
  static String get registerEndpoint => 
      '$backendUrl$apiVersion${dotenv.env['REGISTER_ENDPOINT'] ?? '/auth/register'}';
  
  static String get medicalRecordsEndpoint => 
      '$backendUrl$apiVersion${dotenv.env['MEDICAL_RECORDS_ENDPOINT'] ?? '/medical-records'}';
  
  static String get appointmentsEndpoint => 
      '$backendUrl$apiVersion${dotenv.env['APPOINTMENTS_ENDPOINT'] ?? '/appointments'}';
  
  static String get profileEndpoint => 
      '$backendUrl$apiVersion${dotenv.env['PROFILE_ENDPOINT'] ?? '/user/profile'}';
  
  static String get doctorsEndpoint => 
      '$backendUrl$apiVersion${dotenv.env['DOCTORS_ENDPOINT'] ?? '/doctors'}';
  
  static String get prescriptionsEndpoint => 
      '$backendUrl$apiVersion${dotenv.env['PRESCRIPTIONS_ENDPOINT'] ?? '/prescriptions'}';
  
  static String get labResultsEndpoint => 
      '$backendUrl$apiVersion${dotenv.env['LAB_RESULTS_ENDPOINT'] ?? '/lab-results'}';
  
  static String get uploadDocumentEndpoint => 
      '$backendUrl$apiVersion${dotenv.env['UPLOAD_DOCUMENT_ENDPOINT'] ?? '/upload/document'}';
  
  static String get notificationsEndpoint => 
      '$backendUrl$apiVersion${dotenv.env['NOTIFICATIONS_ENDPOINT'] ?? '/notifications'}';
}