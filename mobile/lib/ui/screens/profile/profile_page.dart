// Subtelas abertas dentro da aba Perfil (a barra de navegação continua visível)
enum ProfilePage { main, achievements, reminders, preferences, help, privacy }

// Abre uma subtela do Perfil (ou volta para a principal com ProfilePage.main)
typedef OpenProfilePage = void Function(ProfilePage page);
