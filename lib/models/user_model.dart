class UserModel {
  final String id;
  final String nome;
  final String cognome;
  final String email;
  final String ruolo;
  UserModel(
      {required this.id,
      required this.nome,
      required this.cognome,
      required this.email,
      required this.ruolo});
  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'],
        nome: json['nome'] ?? '',
        cognome: json['cognome'] ?? '',
        email: json['email'] ?? '',
        ruolo: json['ruolo'] ?? 'cliente',
      );
  bool get isAdmin => ruolo == 'admin';
}
