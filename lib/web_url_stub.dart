// Web URL stub for non-web platforms
library web_url_stub;

class Location {
  String get href => '';
}

class Window {
  Location get location => Location();
}

final Window window = Window();
