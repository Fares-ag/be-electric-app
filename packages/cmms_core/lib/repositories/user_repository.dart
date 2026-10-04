import '../models/company.dart';
import '../models/user.dart';

abstract class UserRepository {
  Future<String> createUser(User user);
  Future<void> updateUser(String userId, User user);
  Future<void> deleteUser(String userId);
  Future<User?> getUserByEmail(String email);
  Future<User?> getUserById(String userId);
  Future<List<User>> getAllUsers();

  Future<List<Company>> getAllCompanies();
  Future<String> createCompany(Company company);
  Future<void> updateCompany(String companyId, Company company);
  Future<void> deleteCompany(String companyId);
  Future<Company?> getCompanyById(String companyId);
}
