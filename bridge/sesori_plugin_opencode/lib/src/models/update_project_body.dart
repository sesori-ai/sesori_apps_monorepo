class UpdateProjectBody {
  final String name;

  const UpdateProjectBody({required this.name});

  Map<String, dynamic> toJson() => {"name": name};
}
