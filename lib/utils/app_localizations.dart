import 'package:flutter/material.dart';

// ─── Classe principale des traductions ───────────────────────────────────────
class AppLocalizations {
  final Locale locale;
  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const delegate = _AppLocalizationsDelegate();

  static const supportedLocales = [
    Locale('fr'),
    Locale('en'),
    Locale('ar'),
    Locale('es'),
    Locale('pt'),
  ];

  String get _lang => locale.languageCode;

  // ─── Navigation ─────────────────────────────────────────────────────────
  String get navMood      => _t({'fr':'Mood',      'en':'Mood',      'ar':'المزاج',   'es':'Humor',    'pt':'Humor'});
  String get navAssistant => _t({'fr':'Mindo',     'en':'Mindo',     'ar':'مندو',     'es':'Mindo',    'pt':'Mindo'});
  String get navCommunity => _t({'fr':'Hub',       'en':'Hub',       'ar':'المجتمع',  'es':'Hub',      'pt':'Hub'});
  String get navPros      => _t({'fr':'Pros',      'en':'Pros',      'ar':'خبراء',    'es':'Pros',     'pt':'Pros'});
  String get navChallenges=> _t({'fr':'Défis',     'en':'Challenges','ar':'تحديات',   'es':'Retos',    'pt':'Desafios'});
  String get navProfile   => _t({'fr':'Profil',    'en':'Profile',   'ar':'الملف',    'es':'Perfil',   'pt':'Perfil'});

  // ─── Mood screen ─────────────────────────────────────────────────────────
  String get howAreYou    => _t({'fr':'Comment tu te sens ?', 'en':'How are you feeling?', 'ar':'كيف حالك؟', 'es':'¿Cómo te sientes?', 'pt':'Como você está?'});
  String get moodGreat    => _t({'fr':'Très bien', 'en':'Great',   'ar':'ممتاز',   'es':'Genial',    'pt':'Ótimo'});
  String get moodGood     => _t({'fr':'Bien',      'en':'Good',    'ar':'جيد',     'es':'Bien',      'pt':'Bem'});
  String get moodNeutral  => _t({'fr':'Neutre',    'en':'Neutral', 'ar':'محايد',   'es':'Neutro',    'pt':'Neutro'});
  String get moodTired    => _t({'fr':'Fatigué(e)','en':'Tired',   'ar':'متعب',    'es':'Cansado/a', 'pt':'Cansado/a'});
  String get moodStressed => _t({'fr':'Stressé(e)','en':'Stressed','ar':'متوتر',   'es':'Estresado/a','pt':'Estressado/a'});
  String get moodAnxious  => _t({'fr':'Anxieux(se)','en':'Anxious','ar':'قلق',     'es':'Ansioso/a', 'pt':'Ansioso/a'});
  String get moodSad      => _t({'fr':'Triste',   'en':'Sad',     'ar':'حزين',    'es':'Triste',    'pt':'Triste'});
  String get logMood      => _t({'fr':'Enregistrer', 'en':'Log mood', 'ar':'تسجيل', 'es':'Registrar', 'pt':'Registrar'});
  String get streakDays   => _t({'fr':'jours consécutifs', 'en':'day streak', 'ar':'أيام متتالية', 'es':'días seguidos', 'pt':'dias seguidos'});

  // ─── Assistant ──────────────────────────────────────────────────────────
  String get mindoTitle       => _t({'fr':'Assistant bien-être · IA', 'en':'Wellness assistant · AI', 'ar':'مساعد الصحة · ذكاء اصطناعي', 'es':'Asistente bienestar · IA', 'pt':'Assistente bem-estar · IA'});
  String get mindoConfidential=> _t({'fr':'Conversation confidentielle', 'en':'Confidential conversation', 'ar':'محادثة سرية', 'es':'Conversación confidencial', 'pt':'Conversa confidencial'});
  String get typeMessage      => _t({'fr':'Écris ce que tu ressens...', 'en':'Write what you feel...', 'ar':'اكتب ما تشعر به...', 'es':'Escribe lo que sientes...', 'pt':'Escreva o que sente...'});
  String get mindoTyping      => _t({'fr':'Mindo réfléchit...', 'en':'Mindo is thinking...', 'ar':'مندو يفكر...', 'es':'Mindo está pensando...', 'pt':'Mindo está pensando...'});
  String get limitReached     => _t({'fr':'Limite quotidienne atteinte', 'en':'Daily limit reached', 'ar':'تم الوصول للحد اليومي', 'es':'Límite diario alcanzado', 'pt':'Limite diário atingido'});
  String get goPremium        => _t({'fr':'Passer en Premium', 'en':'Go Premium', 'ar':'الترقية للبريميوم', 'es':'Ir a Premium', 'pt':'Ir para Premium'});
  String get messagesLeft     => _t({'fr':'restants', 'en':'left', 'ar':'متبقية', 'es':'restantes', 'pt':'restantes'});

  // ─── Communauté ─────────────────────────────────────────────────────────
  String get community        => _t({'fr':'Communauté 🌍', 'en':'Community 🌍', 'ar':'المجتمع 🌍', 'es':'Comunidad 🌍', 'pt':'Comunidade 🌍'});
  String get anonymous        => _t({'fr':'Tout est anonyme', 'en':'Everything is anonymous', 'ar':'كل شيء مجهول', 'es':'Todo es anónimo', 'pt':'Tudo é anônimo'});
  String get share            => _t({'fr':'Partager', 'en':'Share', 'ar':'مشاركة', 'es':'Compartir', 'pt':'Compartilhar'});
  String get myPosts          => _t({'fr':'Mes posts', 'en':'My posts', 'ar':'منشوراتي', 'es':'Mis posts', 'pt':'Meus posts'});
  String get likeAction       => _t({'fr':'J\'aime', 'en':'Like', 'ar':'إعجاب', 'es':'Me gusta', 'pt':'Curtir'});
  String get sameFeeling      => _t({'fr':'Moi aussi', 'en':'Me too', 'ar':'أنا أيضاً', 'es':'Yo también', 'pt':'Eu também'});
  String get comment          => _t({'fr':'Commenter', 'en':'Comment', 'ar':'تعليق', 'es':'Comentar', 'pt':'Comentar'});
  String get newPost          => _t({'fr':'Nouveau partage', 'en':'New post', 'ar':'منشور جديد', 'es':'Nueva publicación', 'pt':'Nova publicação'});
  String get publish          => _t({'fr':'Publier', 'en':'Publish', 'ar':'نشر', 'es':'Publicar', 'pt':'Publicar'});
  String get deletePost       => _t({'fr':'Supprimer ce post ?', 'en':'Delete this post?', 'ar':'حذف هذا المنشور؟', 'es':'¿Eliminar este post?', 'pt':'Excluir este post?'});
  String get searchPosts      => _t({'fr':'Rechercher...', 'en':'Search...', 'ar':'بحث...', 'es':'Buscar...', 'pt':'Pesquisar...'});

  // ─── Professionnels ──────────────────────────────────────────────────────
  String get professionals    => _t({'fr':'Professionnels', 'en':'Professionals', 'ar':'المختصون', 'es':'Profesionales', 'pt':'Profissionais'});
  String get bookConsultation => _t({'fr':'Prendre rendez-vous', 'en':'Book consultation', 'ar':'حجز استشارة', 'es':'Reservar consulta', 'pt':'Agendar consulta'});
  String get online           => _t({'fr':'En ligne', 'en':'Online', 'ar':'عبر الإنترنت', 'es':'En línea', 'pt':'Online'});
  String get inPerson         => _t({'fr':'En présentiel', 'en':'In person', 'ar':'حضوري', 'es':'Presencial', 'pt':'Presencial'});

  // ─── Défis ───────────────────────────────────────────────────────────────
  String get challenges       => _t({'fr':'Défis du jour', 'en':'Daily challenges', 'ar':'تحديات اليوم', 'es':'Retos del día', 'pt':'Desafios do dia'});
  String get complete         => _t({'fr':'Terminer', 'en':'Complete', 'ar':'إنهاء', 'es':'Completar', 'pt':'Completar'});
  String get completed        => _t({'fr':'Complété ✓', 'en':'Completed ✓', 'ar':'تم ✓', 'es':'Completado ✓', 'pt':'Concluído ✓'});
  String get points           => _t({'fr':'pts', 'en':'pts', 'ar':'نقطة', 'es':'pts', 'pt':'pts'});

  // ─── Profil ──────────────────────────────────────────────────────────────
  String get profile          => _t({'fr':'Mon profil', 'en':'My profile', 'ar':'ملفي', 'es':'Mi perfil', 'pt':'Meu perfil'});
  String get settings         => _t({'fr':'Paramètres', 'en':'Settings', 'ar':'الإعدادات', 'es':'Ajustes', 'pt':'Configurações'});
  String get logout           => _t({'fr':'Se déconnecter', 'en':'Log out', 'ar':'تسجيل الخروج', 'es':'Cerrar sesión', 'pt':'Sair'});
  String get deleteAccount    => _t({'fr':'Supprimer mon compte', 'en':'Delete my account', 'ar':'حذف حسابي', 'es':'Eliminar mi cuenta', 'pt':'Excluir minha conta'});
  String get exportData       => _t({'fr':'Exporter mes données', 'en':'Export my data', 'ar':'تصدير بياناتي', 'es':'Exportar mis datos', 'pt':'Exportar meus dados'});

  // ─── Auth ────────────────────────────────────────────────────────────────
  String get login            => _t({'fr':'Connexion', 'en':'Log in', 'ar':'تسجيل الدخول', 'es':'Iniciar sesión', 'pt':'Entrar'});
  String get register         => _t({'fr':'Créer un compte', 'en':'Create account', 'ar':'إنشاء حساب', 'es':'Crear cuenta', 'pt':'Criar conta'});
  String get email            => _t({'fr':'Email', 'en':'Email', 'ar':'البريد الإلكتروني', 'es':'Correo', 'pt':'E-mail'});
  String get password         => _t({'fr':'Mot de passe', 'en':'Password', 'ar':'كلمة المرور', 'es':'Contraseña', 'pt':'Senha'});
  String get forgotPassword   => _t({'fr':'Mot de passe oublié ?', 'en':'Forgot password?', 'ar':'نسيت كلمة المرور؟', 'es':'¿Olvidaste tu contraseña?', 'pt':'Esqueceu a senha?'});

  // ─── Paramètres ─────────────────────────────────────────────────────────
  String get appearance       => _t({'fr':'Apparence', 'en':'Appearance', 'ar':'المظهر', 'es':'Apariencia', 'pt':'Aparência'});
  String get language         => _t({'fr':'Langue', 'en':'Language', 'ar':'اللغة', 'es':'Idioma', 'pt':'Idioma'});
  String get notifications    => _t({'fr':'Notifications', 'en':'Notifications', 'ar':'الإشعارات', 'es':'Notificaciones', 'pt':'Notificações'});
  String get darkMode         => _t({'fr':'Thème sombre', 'en':'Dark mode', 'ar':'الوضع الداكن', 'es':'Modo oscuro', 'pt':'Modo escuro'});
  String get textSize         => _t({'fr':'Taille du texte', 'en':'Text size', 'ar':'حجم النص', 'es':'Tamaño de texto', 'pt':'Tamanho do texto'});
  String get dailyReminder    => _t({'fr':'Rappel humeur quotidien', 'en':'Daily mood reminder', 'ar':'تذكير المزاج اليومي', 'es':'Recordatorio de humor diario', 'pt':'Lembrete diário de humor'});

  // ─── Commun ──────────────────────────────────────────────────────────────
  String get cancel           => _t({'fr':'Annuler', 'en':'Cancel', 'ar':'إلغاء', 'es':'Cancelar', 'pt':'Cancelar'});
  String get confirm          => _t({'fr':'Confirmer', 'en':'Confirm', 'ar':'تأكيد', 'es':'Confirmar', 'pt':'Confirmar'});
  String get save             => _t({'fr':'Enregistrer', 'en':'Save', 'ar':'حفظ', 'es':'Guardar', 'pt':'Salvar'});
  String get loading          => _t({'fr':'Chargement...', 'en':'Loading...', 'ar':'جارٍ التحميل...', 'es':'Cargando...', 'pt':'Carregando...'});
  String get error            => _t({'fr':'Une erreur est survenue', 'en':'An error occurred', 'ar':'حدث خطأ', 'es':'Ocurrió un error', 'pt':'Ocorreu um erro'});
  String get retry            => _t({'fr':'Réessayer', 'en':'Retry', 'ar':'إعادة المحاولة', 'es':'Reintentar', 'pt':'Tentar novamente'});
  String get yes              => _t({'fr':'Oui', 'en':'Yes', 'ar':'نعم', 'es':'Sí', 'pt':'Sim'});
  String get no               => _t({'fr':'Non', 'en':'No', 'ar':'لا', 'es':'No', 'pt':'Não'});
  String get back             => _t({'fr':'Retour', 'en':'Back', 'ar':'رجوع', 'es':'Volver', 'pt':'Voltar'});
  String get close            => _t({'fr':'Fermer', 'en':'Close', 'ar':'إغلاق', 'es':'Cerrar', 'pt':'Fechar'});

  // ─── Helper interne ───────────────────────────────────────────────────────
  String _t(Map<String, String> translations) =>
      translations[_lang] ?? translations['fr'] ?? translations.values.first;
}

// ─── Delegate ────────────────────────────────────────────────────────────────
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['fr', 'en', 'ar', 'es', 'pt'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}