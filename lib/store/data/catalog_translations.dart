typedef CatalogCopy = Map<String, Map<String, String>>;

CatalogCopy parseCatalogCopy(dynamic value) {
  if (value is! Map) return const {};
  return {
    for (final locale in ['ar', 'en'])
      if (value[locale] is Map)
        locale: {
          for (final entry in (value[locale] as Map).entries)
            if (entry.value is String)
              entry.key.toString(): entry.value as String,
        },
  };
}
