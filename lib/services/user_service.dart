class AppUser {
  final String id;
  final String name;
  final String password;
  final String role; // 'employee' 或 'boss'
  final String department;

  const AppUser({
    required this.id,
    required this.name,
    required this.password,
    required this.role,
    required this.department,
  });
}

class UserService {
  // 模拟用户数据（以后替换为后端 API）
  static final List<AppUser> users = [
    AppUser(
      id: '001',
      name: '张三',
      password: '123456',
      role: 'employee',
      department: '技术部',
    ),
    AppUser(
      id: '002',
      name: '李四',
      password: '123456',
      role: 'employee',
      department: '市场部',
    ),
    AppUser(
      id: 'boss001',
      name: '王老板',
      password: '123456',
      role: 'boss',
      department: '管理层',
    ),
  ];

  static AppUser? login(String id, String password) {
    try {
      return users.firstWhere((u) => u.id == id && u.password == password);
    } catch (_) {
      return null;
    }
  }

  static AppUser? getUserById(String id) {
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  static bool updateUser(String id, {String? name, String? department}) {
    try {
      final user = users.firstWhere((u) => u.id == id);
      final index = users.indexOf(user);
      users[index] = AppUser(
        id: user.id,
        name: name ?? user.name,
        password: user.password,
        role: user.role,
        department: department ?? user.department,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  static void upsertRemoteUser({
    required String id,
    required String name,
    required String role,
    required String department,
  }) {
    final index = users.indexWhere((user) => user.id == id);
    final remoteUser = AppUser(
      id: id,
      name: name,
      password: '',
      role: role,
      department: department,
    );
    if (index == -1) {
      users.add(remoteUser);
    } else {
      users[index] = remoteUser;
    }
  }

  // Legacy local registration remains temporarily available during migration.
  static String? register({
    required String id,
    required String name,
    required String password,
    required String department,
    required String role,
  }) {
    // 检查工号是否已存在
    if (users.any((u) => u.id == id)) {
      return 'Employee ID already exists';
    }
    users.add(
      AppUser(
        id: id,
        name: name,
        password: password,
        role: role,
        department: department,
      ),
    );
    return null; // 成功
  }
}
