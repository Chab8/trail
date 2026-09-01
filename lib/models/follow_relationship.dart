/// Representa la relación entre "yo" (el usuario logueado) y otro usuario.
enum FollowRelationship {
  /// No lo sigo ni le mandé solicitud.
  none,

  /// Ya lo sigo.
  following,

  /// Le mandé una solicitud de seguimiento y todavía no me respondió
  /// (esto solo pasa con perfiles privados).
  requested,
}