/// The only two pours this app knows about: an Israeli pub shlish and hatzi.
enum BeerSize {
  third(333, '⅓', '1/3'),
  half(500, '½', '1/2');

  const BeerSize(this.ml, this.glyph, this.label);

  final int ml;
  final String glyph;
  final String label;

  static BeerSize? fromMl(int ml) {
    for (final size in values) {
      if (size.ml == ml) return size;
    }
    return null;
  }
}
