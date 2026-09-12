class Person {
  const Person({required this.id, required this.name});

  static const meId = 'me';
  static const partnerId = 'partner';
  static const bothId = 'both';

  final String id;
  final String name;

  Person copyWith({String? name}) => Person(id: id, name: name ?? this.name);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: json['id'] as String,
        name: json['name'] as String,
      );
}

class Household {
  const Household({required this.me, required this.partner});

  final Person me;
  final Person partner;

  static const defaults = Household(
    me: Person(id: Person.meId, name: 'Aš'),
    partner: Person(id: Person.partnerId, name: 'Žmona'),
  );

  List<Person> get members => [me, partner];

  Person byId(String id) {
    if (id == partner.id) return partner;
    return me;
  }

  Household copyWith({Person? me, Person? partner}) => Household(
        me: me ?? this.me,
        partner: partner ?? this.partner,
      );

  Map<String, dynamic> toJson() => {
        'me': me.toJson(),
        'partner': partner.toJson(),
      };

  factory Household.fromJson(Map<String, dynamic> json) => Household(
        me: Person.fromJson(json['me'] as Map<String, dynamic>),
        partner: Person.fromJson(json['partner'] as Map<String, dynamic>),
      );
}
