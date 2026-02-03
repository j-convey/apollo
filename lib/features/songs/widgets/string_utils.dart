class StringUtils {
  /// Sanitizes a string for sorting by removing special characters like ' and ( ).
  /// This ensures that titles are sorted based on their alphanumeric content.
  static String toSortable(String text) {
    if (text.isEmpty) return text;
    // Remove non-alphanumeric characters (except spaces) and convert to lowercase
    return text.replaceAll(RegExp(r"[^a-zA-Z0-9\s]"), "").toLowerCase().trim();
  }
}