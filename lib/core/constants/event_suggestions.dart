/// Category of event for icon selection
enum EventCategory {
  birthday,
  wedding,
  heart,
  diamond,
  gift,
  star,
  baby,
  graduation,
  house,
  trophy,
  travel,
  car,
  camping,
  party,
  users,
  flower,
}

/// Model for a date-sensitive event suggestion
class EventSuggestion {
  final String name;
  final String? description;
  final EventCategory category;
  final bool isRecurringByDefault;
  final List<String> keywords;

  /// Fixed month (1-12) if the date is known
  final int? fixedMonth;

  /// Fixed day (1-31) if the date is known
  final int? fixedDay;

  const EventSuggestion({
    required this.name,
    this.description,
    required this.category,
    this.isRecurringByDefault = false,
    this.keywords = const [],
    this.fixedMonth,
    this.fixedDay,
  });

  /// Returns true if this event has a known fixed date
  bool get hasFixedDate => fixedMonth != null && fixedDay != null;

  /// Get the next occurrence of this fixed date
  DateTime? getNextDate() {
    if (!hasFixedDate) return null;

    final now = DateTime.now();
    var date = DateTime(now.year, fixedMonth!, fixedDay!);

    // If the date has passed this year, use next year
    if (date.isBefore(now)) {
      date = DateTime(now.year + 1, fixedMonth!, fixedDay!);
    }

    return date;
  }

  /// Check if this suggestion matches the search query
  bool matches(String query) {
    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) return false;

    // Check name
    if (name.toLowerCase().contains(lowerQuery)) return true;

    // Check keywords
    for (final keyword in keywords) {
      if (keyword.toLowerCase().contains(lowerQuery)) return true;
    }

    return false;
  }
}

/// List of common date-sensitive events
class EventSuggestions {
  static const List<EventSuggestion> all = [
    // Celebrations
    EventSuggestion(
      name: 'Birthday',
      description: 'Annual birthday celebration',
      category: EventCategory.birthday,
      isRecurringByDefault: true,
      keywords: ['bday', 'birth', 'born', 'age'],
    ),
    EventSuggestion(
      name: 'Wedding',
      description: 'Wedding day gifts',
      category: EventCategory.wedding,
      isRecurringByDefault: false,
      keywords: ['marry', 'marriage', 'bride', 'groom', 'nuptials', 'bridal'],
    ),
    EventSuggestion(
      name: 'Anniversary',
      description: 'Wedding or relationship anniversary',
      category: EventCategory.heart,
      isRecurringByDefault: true,
      keywords: ['anniv', 'married', 'years together'],
    ),
    EventSuggestion(
      name: 'Engagement',
      description: 'Engagement celebration',
      category: EventCategory.diamond,
      isRecurringByDefault: false,
      keywords: ['engaged', 'proposal', 'ring'],
    ),

    // Holidays with fixed dates
    EventSuggestion(
      name: 'Christmas',
      description: 'Christmas gift ideas',
      category: EventCategory.gift,
      isRecurringByDefault: true,
      keywords: ['xmas', 'holiday', 'santa', 'december 25'],
      fixedMonth: 12,
      fixedDay: 25,
    ),
    EventSuggestion(
      name: 'Christmas Eve',
      description: 'Christmas Eve celebration',
      category: EventCategory.gift,
      isRecurringByDefault: true,
      keywords: ['xmas eve', 'december 24'],
      fixedMonth: 12,
      fixedDay: 24,
    ),
    EventSuggestion(
      name: 'New Year',
      description: 'New Year celebration',
      category: EventCategory.party,
      isRecurringByDefault: true,
      keywords: ['january 1', 'new years day'],
      fixedMonth: 1,
      fixedDay: 1,
    ),
    EventSuggestion(
      name: 'New Year\'s Eve',
      description: 'New Year\'s Eve party',
      category: EventCategory.party,
      isRecurringByDefault: true,
      keywords: ['nye', 'december 31', 'countdown'],
      fixedMonth: 12,
      fixedDay: 31,
    ),
    EventSuggestion(
      name: 'Valentine\'s Day',
      description: 'Valentine\'s Day gifts',
      category: EventCategory.heart,
      isRecurringByDefault: true,
      keywords: ['valentines', 'love', 'february 14', 'romantic'],
      fixedMonth: 2,
      fixedDay: 14,
    ),
    EventSuggestion(
      name: 'Halloween',
      description: 'Halloween celebration',
      category: EventCategory.gift,
      isRecurringByDefault: true,
      keywords: ['spooky', 'october 31', 'costume', 'trick or treat'],
      fixedMonth: 10,
      fixedDay: 31,
    ),
    EventSuggestion(
      name: 'St Patrick\'s Day',
      description: 'St Patrick\'s Day celebration',
      category: EventCategory.party,
      isRecurringByDefault: true,
      keywords: ['saint', 'irish', 'ireland', 'march 17', 'green', 'paddy'],
      fixedMonth: 3,
      fixedDay: 17,
    ),
    EventSuggestion(
      name: 'St George\'s Day',
      description: 'England\'s patron saint day',
      category: EventCategory.party,
      isRecurringByDefault: true,
      keywords: ['saint', 'english', 'england', 'april 23', 'george'],
      fixedMonth: 4,
      fixedDay: 23,
    ),
    EventSuggestion(
      name: 'St Andrew\'s Day',
      description: 'Scotland\'s patron saint day',
      category: EventCategory.party,
      isRecurringByDefault: true,
      keywords: ['saint', 'scottish', 'scotland', 'november 30', 'andrew'],
      fixedMonth: 11,
      fixedDay: 30,
    ),
    EventSuggestion(
      name: 'St David\'s Day',
      description: 'Wales\' patron saint day',
      category: EventCategory.party,
      isRecurringByDefault: true,
      keywords: [
        'saint',
        'welsh',
        'wales',
        'march 1',
        'david',
        'dydd gwyl dewi',
      ],
      fixedMonth: 3,
      fixedDay: 1,
    ),
    EventSuggestion(
      name: 'Independence Day',
      description: 'July 4th celebration',
      category: EventCategory.party,
      isRecurringByDefault: true,
      keywords: ['july 4', 'fourth of july', '4th of july', 'american'],
      fixedMonth: 7,
      fixedDay: 4,
    ),
    EventSuggestion(
      name: 'Kwanzaa',
      description: 'African heritage celebration',
      category: EventCategory.star,
      isRecurringByDefault: true,
      keywords: ['african', 'heritage', 'december 26'],
      fixedMonth: 12,
      fixedDay: 26,
    ),

    // Holidays with variable dates (lunar/calculated)
    EventSuggestion(
      name: 'Hanukkah',
      description: 'Festival of lights',
      category: EventCategory.star,
      isRecurringByDefault: true,
      keywords: ['chanukah', 'festival of lights', 'menorah', 'jewish'],
    ),
    EventSuggestion(
      name: 'Easter',
      description: 'Easter celebration',
      category: EventCategory.gift,
      isRecurringByDefault: true,
      keywords: ['bunny', 'eggs', 'spring', 'resurrection'],
    ),
    EventSuggestion(
      name: 'Thanksgiving',
      description: 'Thanksgiving gathering',
      category: EventCategory.heart,
      isRecurringByDefault: true,
      keywords: ['turkey', 'november', 'gratitude'],
    ),
    EventSuggestion(
      name: 'Mother\'s Day',
      description: 'Mother\'s Day gifts',
      category: EventCategory.flower,
      isRecurringByDefault: true,
      keywords: ['mom', 'mum', 'mama', 'mother'],
    ),
    EventSuggestion(
      name: 'Father\'s Day',
      description: 'Father\'s Day gifts',
      category: EventCategory.gift,
      isRecurringByDefault: true,
      keywords: ['dad', 'papa', 'father', 'daddy'],
    ),

    // Islamic Holidays (lunar calendar - dates vary)
    EventSuggestion(
      name: 'Eid al-Fitr',
      description: 'End of Ramadan celebration',
      category: EventCategory.star,
      isRecurringByDefault: true,
      keywords: ['eid', 'fitr', 'ramadan', 'islamic', 'muslim', 'iftar'],
    ),
    EventSuggestion(
      name: 'Eid al-Adha',
      description: 'Festival of Sacrifice',
      category: EventCategory.star,
      isRecurringByDefault: true,
      keywords: ['eid', 'adha', 'qurbani', 'islamic', 'muslim', 'hajj'],
    ),
    EventSuggestion(
      name: 'Ramadan',
      description: 'Holy month of fasting',
      category: EventCategory.star,
      isRecurringByDefault: true,
      keywords: ['fasting', 'islamic', 'muslim', 'iftar', 'suhoor'],
    ),

    // Hindu Holidays (lunar calendar - dates vary)
    EventSuggestion(
      name: 'Diwali',
      description: 'Festival of Lights',
      category: EventCategory.star,
      isRecurringByDefault: true,
      keywords: ['deepavali', 'hindu', 'lights', 'indian'],
    ),
    EventSuggestion(
      name: 'Holi',
      description: 'Festival of Colors',
      category: EventCategory.party,
      isRecurringByDefault: true,
      keywords: ['colors', 'colours', 'hindu', 'indian', 'spring'],
    ),

    // Other Cultural Holidays
    EventSuggestion(
      name: 'Lunar New Year',
      description: 'Chinese New Year celebration',
      category: EventCategory.party,
      isRecurringByDefault: true,
      keywords: ['chinese new year', 'spring festival', 'lunar', 'asian'],
    ),

    // Life Events
    EventSuggestion(
      name: 'Baby Shower',
      description: 'Baby shower gifts',
      category: EventCategory.baby,
      isRecurringByDefault: false,
      keywords: ['baby', 'expecting', 'pregnant', 'newborn', 'shower'],
    ),
    EventSuggestion(
      name: 'Graduation',
      description: 'Graduation gifts',
      category: EventCategory.graduation,
      isRecurringByDefault: false,
      keywords: ['grad', 'graduate', 'diploma', 'degree', 'school'],
    ),
    EventSuggestion(
      name: 'Retirement',
      description: 'Retirement celebration',
      category: EventCategory.gift,
      isRecurringByDefault: false,
      keywords: ['retire', 'retired', 'pension'],
    ),
    EventSuggestion(
      name: 'Housewarming',
      description: 'New home gifts',
      category: EventCategory.house,
      isRecurringByDefault: false,
      keywords: ['new home', 'moving', 'house', 'apartment', 'moved'],
    ),
    EventSuggestion(
      name: 'Promotion',
      description: 'Work promotion celebration',
      category: EventCategory.trophy,
      isRecurringByDefault: false,
      keywords: ['work', 'job', 'career', 'promoted'],
    ),

    // Travel & Activities
    EventSuggestion(
      name: 'Vacation',
      description: 'Vacation trip planning',
      category: EventCategory.travel,
      isRecurringByDefault: false,
      keywords: ['trip', 'travel', 'holiday', 'getaway', 'journey'],
    ),
    EventSuggestion(
      name: 'Honeymoon',
      description: 'Honeymoon trip',
      category: EventCategory.travel,
      isRecurringByDefault: false,
      keywords: ['wedding trip', 'newlywed', 'romantic getaway'],
    ),
    EventSuggestion(
      name: 'Road Trip',
      description: 'Road trip adventure',
      category: EventCategory.car,
      isRecurringByDefault: false,
      keywords: ['drive', 'driving', 'car trip'],
    ),
    EventSuggestion(
      name: 'Camping',
      description: 'Camping trip',
      category: EventCategory.camping,
      isRecurringByDefault: false,
      keywords: ['camp', 'outdoors', 'nature', 'hiking'],
    ),

    // Gatherings
    EventSuggestion(
      name: 'Party',
      description: 'Party celebration',
      category: EventCategory.party,
      isRecurringByDefault: false,
      keywords: ['celebrate', 'celebration', 'gathering'],
    ),
    EventSuggestion(
      name: 'Reunion',
      description: 'Family or class reunion',
      category: EventCategory.users,
      isRecurringByDefault: false,
      keywords: ['family', 'class', 'get together'],
    ),
    EventSuggestion(
      name: 'Secret Santa',
      description: 'Secret Santa gift exchange',
      category: EventCategory.gift,
      isRecurringByDefault: true,
      keywords: ['kris kringle', 'gift exchange', 'white elephant'],
    ),
  ];

  /// Get suggestions that match the query
  static List<EventSuggestion> search(String query) {
    if (query.trim().isEmpty) return [];

    return all.where((suggestion) => suggestion.matches(query)).toList();
  }
}
