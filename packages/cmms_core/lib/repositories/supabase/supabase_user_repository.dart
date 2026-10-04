import '../../models/company.dart';
import '../../models/user.dart';
import '../../services/supabase_database_service.dart';
import '../user_repository.dart';
import '../../config/locator.dart';

class SupabaseUserRepository implements UserRepository {
  SupabaseUserRepository({SupabaseDatabaseService? database})
      : _database = database ?? sl<SupabaseDatabaseService>();

  final SupabaseDatabaseService _database;

  @override
  Future<String> createUser(User user) => _database.createUser(user);

  @override
  Future<void> updateUser(String userId, User user) =>
      _database.updateUser(userId, user);

  @override
  Future<void> deleteUser(String userId) => _database.deleteUser(userId);

  @override
  Future<User?> getUserByEmail(String email) =>
      _database.getUserByEmail(email);

  @override
  Future<User?> getUserById(String userId) => _database.getUserById(userId);

  @override
  Future<List<User>> getAllUsers() => _database.getAllUsers();

  @override
  Future<List<Company>> getAllCompanies() => _database.getAllCompanies();

  @override
  Future<String> createCompany(Company company) =>
      _database.createCompany(company);

  @override
  Future<void> updateCompany(String companyId, Company company) =>
      _database.updateCompany(companyId, company);

  @override
  Future<void> deleteCompany(String companyId) =>
      _database.deleteCompany(companyId);

  @override
  Future<Company?> getCompanyById(String companyId) =>
      _database.getCompanyById(companyId);
}
