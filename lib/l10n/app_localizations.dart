import 'package:flutter/widgets.dart';

class AppLocalizations {
  const AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('es'),
    Locale('ru'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('es'));
  }

  bool get isRussian => locale.languageCode == 'ru';

  String get appTitle => 'BRIMOON Studio';
  String get calendar => isRussian ? 'Календарь' : 'Calendario';
  String get booking => isRussian ? 'Запись' : 'Reserva';
  String get clients => isRussian ? 'Клиенты' : 'Clientes';
  String get salon => isRussian ? 'Салон' : 'Salon';
  String get settings => isRussian ? 'Настройки' : 'Ajustes';

  String get loginSubtitle => isRussian
      ? 'Войдите в календарь и записи.'
      : 'Accede a tu calendario y reservas.';
  String get username => isRussian ? 'Пользователь' : 'Usuario';
  String get password => isRussian ? 'Пароль' : 'Contrasena';
  String get enterUsername =>
      isRussian ? 'Введите пользователя' : 'Introduce usuario';
  String get enterPassword =>
      isRussian ? 'Введите пароль' : 'Introduce contrasena';
  String get signIn => isRussian ? 'Войти' : 'Entrar';
  String get forgotPassword =>
      isRussian ? 'Забыли пароль' : 'Olvide mi contrasena';
  String get recoverPassword =>
      isRussian ? 'Восстановить пароль' : 'Recuperar contrasena';
  String get recoverPasswordHelp => isRussian
      ? 'Отправьте заявку в WhatsApp, чтобы администратор выдал новый доступ.'
      : 'Enviaremos una solicitud por WhatsApp para que administracion te entregue un nuevo acceso.';
  String get usernameEmailPhone => isRussian
      ? 'Пользователь, email или телефон'
      : 'Usuario, email o telefono';
  String get copy => isRussian ? 'Копировать' : 'Copiar';
  String get whatsapp => 'WhatsApp';
  String get accessRequestCopied =>
      isRussian ? 'Заявка скопирована.' : 'Solicitud copiada.';
  String get cantOpenWhatsApp =>
      isRussian ? 'Не удалось открыть WhatsApp.' : 'No se pudo abrir WhatsApp.';
  String get enterRecoveryContact => isRussian
      ? 'Введите пользователя, email или телефон.'
      : 'Introduce tu usuario, email o telefono.';
  String recoveryMessage(String contact) {
    if (isRussian) {
      return 'Здравствуйте, мне нужно восстановить доступ к BRIMOON Studio.\n\n'
          'Пользователь, email или телефон: $contact\n\n'
          'Пожалуйста, отправьте мне имя пользователя или новый пароль.';
    }
    return 'Hola, necesito recuperar el acceso a BRIMOON Studio.\n\n'
        'Usuario, email o telefono: $contact\n\n'
        'Por favor, enviadme mi usuario o una nueva contrasena.';
  }

  String get appearance => isRussian ? 'Внешний вид' : 'Apariencia';
  String get appColor =>
      isRussian ? 'Цвет приложения' : 'Color de la aplicacion';
  String get textSize => isRussian ? 'Размер текста' : 'Tamano de texto';
  String get language => isRussian ? 'Язык' : 'Idioma';
  String get spanish => isRussian ? 'Испанский' : 'Espanol';
  String get russian => isRussian ? 'Русский' : 'Ruso';
  String get myAccount => isRussian ? 'Мой аккаунт' : 'Mi cuenta';
  String get firstName => isRussian ? 'Имя' : 'Nombre';
  String get lastName => isRussian ? 'Фамилия' : 'Apellido';
  String get invalidEmail => isRussian ? 'Неверный email' : 'Email invalido';
  String get changePassword =>
      isRussian ? 'Сменить пароль' : 'Cambiar contrasena';
  String get currentPassword =>
      isRussian ? 'Текущий пароль' : 'Contrasena actual';
  String get newPassword => isRussian ? 'Новый пароль' : 'Nueva contrasena';
  String get confirmNewPassword =>
      isRussian ? 'Подтвердите новый пароль' : 'Confirmar nueva contrasena';
  String get enterCurrentPassword =>
      isRussian ? 'Введите текущий пароль' : 'Introduce la contrasena actual';
  String get minFourChars =>
      isRussian ? 'Минимум 4 символа' : 'Minimo 4 caracteres';
  String get passwordsDontMatch =>
      isRussian ? 'Пароли не совпадают' : 'Las contrasenas no coinciden';
  String get saveChanges => isRussian ? 'Сохранить' : 'Guardar cambios';
  String get profileUpdated =>
      isRussian ? 'Профиль обновлен.' : 'Perfil actualizado.';
  String get signOut => isRussian ? 'Выйти' : 'Cerrar sesion';
  String get refresh => isRussian ? 'Обновить' : 'Actualizar';
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) {
    return AppLocalizations.supportedLocales
        .any((item) => item.languageCode == locale.languageCode);
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    final normalized = isSupported(locale) ? locale : const Locale('es');
    return AppLocalizations(Locale(normalized.languageCode));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
