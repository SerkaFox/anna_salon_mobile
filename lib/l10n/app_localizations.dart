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

  String tr(String spanish) {
    if (!isRussian) return spanish;
    return _ru[spanish] ?? spanish;
  }

  String employeesCount(int count) =>
      isRussian ? '$count сотрудников' : '$count empleados';
  String visibleCount(int count) =>
      isRussian ? '$count видно' : '$count visibles';
  String clientsCount(int count) =>
      isRussian ? '$count клиентов' : '$count clientes';
  String commission(String value) =>
      isRussian ? 'Комиссия $value%' : 'Comision $value%';
  String selectField(String label) =>
      isRussian ? 'Выберите: $label' : 'Selecciona $label';

  static const Map<String, String> _ru = {
    'Empleados': 'Сотрудники',
    'Mi ficha': 'Моя карточка',
    'Buscar empleado': 'Найти сотрудника',
    'Nombre, telefono, email o servicio': 'Имя, телефон, email или услуга',
    'No hay empleados todavia.': 'Сотрудников пока нет.',
    'No hay empleados para esta busqueda.': 'По этому поиску сотрудников нет.',
    'Eliminar empleado': 'Удалить сотрудника',
    'Cancelar': 'Отмена',
    'Eliminar': 'Удалить',
    'Empleado eliminado.': 'Сотрудник удален.',
    'Informacion': 'Информация',
    'Sin telefono': 'Без телефона',
    'Sin email': 'Без email',
    'Sin fecha de nacimiento': 'Дата рождения не указана',
    'Sin recomendado por': 'Рекомендатель не указан',
    'Sin usuario vinculado': 'Пользователь не привязан',
    'Servicios': 'Услуги',
    'No definidos.': 'Не указаны.',
    'Servicios mas realizados': 'Самые частые услуги',
    'Gana empleado': 'Сотрудник получает',
    'Facturado': 'Выручка',
    'Salon': 'Салон',
    'Visitas': 'Визиты',
    'Clientes': 'Клиенты',
    'Ticket medio': 'Средний чек',
    'Periodo de estadistica': 'Период статистики',
    'Este mes': 'Этот месяц',
    'Mes pasado': 'Прошлый месяц',
    'Todo': 'Все',
    'Rango': 'Период',
    'Todo el periodo': 'Весь период',
    'Clientes habituales': 'Постоянные клиенты',
    'Reservas': 'Записи',
    'Sin datos.': 'Нет данных.',
    'Sin reservas.': 'Записей нет.',
    'Usuario copiado.': 'Пользователь скопирован.',
    'Hace falta telefono, usuario y nueva contrasena.':
        'Нужны телефон, пользователь и новый пароль.',
    'No se pudo abrir WhatsApp.': 'Не удалось открыть WhatsApp.',
    'Nuevo empleado': 'Новый сотрудник',
    'Editar empleado': 'Редактировать сотрудника',
    'Mi perfil y servicios': 'Мой профиль и услуги',
    'Nombre': 'Имя',
    'Introduce el nombre': 'Введите имя',
    'Apellidos': 'Фамилия',
    'Telefono': 'Телефон',
    'Color calendario': 'Цвет календаря',
    'Usuario para entrar': 'Пользователь для входа',
    'Copiar usuario': 'Скопировать пользователя',
    'Generar nueva contrasena': 'Создать новый пароль',
    'Generar contrasena': 'Создать пароль',
    'Contrasena inicial': 'Первоначальный пароль',
    'Nueva contrasena': 'Новый пароль',
    'Introduce una contrasena inicial': 'Введите первоначальный пароль',
    'Introduce un usuario': 'Введите пользователя',
    'Minimo 4 caracteres': 'Минимум 4 символа',
    'Comision %': 'Комиссия %',
    'Activo': 'Активен',
    'Inactivo': 'Неактивен',
    'Notas': 'Заметки',
    'Crear empleado': 'Создать сотрудника',
    'Guardar': 'Сохранить',
    'Horario': 'График',
    'Editar horario': 'Изменить график',
    'Horario de trabajo': 'Рабочий график',
    'Guardar horario': 'Сохранить график',
    'Horario guardado.': 'График сохранен.',
    'Dia libre': 'Выходной',
    'Trabaja': 'Работает',
    'Desde': 'С',
    'Hasta': 'До',
    'Pausa desde': 'Пауза с',
    'Pausa hasta': 'Пауза до',
    'Nota': 'Заметка',
    'Dias especiales': 'Особые дни',
    'Anadir dia especial': 'Добавить особый день',
    'Fecha': 'Дата',
    'Etiqueta': 'Метка',
    'Sin dias especiales.': 'Особых дней нет.',
    'Lunes': 'Понедельник',
    'Martes': 'Вторник',
    'Miercoles': 'Среда',
    'Jueves': 'Четверг',
    'Viernes': 'Пятница',
    'Sabado': 'Суббота',
    'Domingo': 'Воскресенье',
    'Lu': 'Пн',
    'Ma': 'Вт',
    'Mi': 'Ср',
    'Ju': 'Чт',
    'Vi': 'Пт',
    'Sa': 'Сб',
    'Do': 'Вс',
    'Servicios disponibles': 'Доступные услуги',
    'Servicio': 'Услуга',
    'Crear': 'Создать',
    'Buscar': 'Поиск',
    'No hay resultados.': 'Нет результатов.',
    'Datos de la reserva': 'Данные записи',
    'Selecciona cliente, empleado, servicio y horario.':
        'Выберите клиента, сотрудника, услугу и время.',
    'Cliente': 'Клиент',
    'Crear cliente': 'Создать клиента',
    'Nombre, apellido, telefono, email o login':
        'Имя, фамилия, телефон, email или логин',
    'Este empleado no tiene servicios disponibles':
        'У этого сотрудника нет доступных услуг',
    'Nombre o descripcion del servicio': 'Название или описание услуги',
    'Zona requerida': 'Нужна зона',
    'Sin zona': 'Без зоны',
    'Este servicio no tiene empleados disponibles':
        'У этой услуги нет доступных сотрудников',
    'Empleado': 'Сотрудник',
    'Este servicio requiere zona': 'Для этой услуги нужна зона',
    'Zona': 'Зона',
    'Foto antes': 'Фото до',
    'Foto despues': 'Фото после',
    'Camara': 'Камера',
    'Galeria': 'Галерея',
    'Nueva reserva': 'Новая запись',
    'Origen de la reserva': 'Источник записи',
    'En el salon': 'В салоне',
    'Por recomendacion': 'По рекомендации',
    'Por empleado': 'От сотрудника',
    'Selecciona servicio, empleado y zona':
        'Выберите услугу, сотрудника и зону',
    'Sin datos de disponibilidad': 'Нет данных о доступности',
    'No hay horarios disponibles': 'Нет доступного времени',
    'Este cliente aun no tiene premios disponibles.':
        'У этого клиента пока нет доступных бонусов.',
    'Selecciona cliente para ver premios.':
        'Выберите клиента, чтобы увидеть бонусы.',
    'Cargando premios...': 'Загрузка бонусов...',
    'Premio del cliente': 'Бонус клиента',
    'No aplicar premio': 'Не применять бонус',
    'Premio': 'Бонус',
    'Hora': 'Время',
    'Hora disponible': 'Доступное время',
    'Buscando horarios...': 'Идет поиск времени...',
    'Zonas': 'Зоны',
    'Premios': 'Бонусы',
    'Crear servicio': 'Создать услугу',
    'Editar servicio': 'Редактировать услугу',
    'Eliminar servicio': 'Удалить услугу',
    'Servicio eliminado.': 'Услуга удалена.',
    'Crear zona': 'Создать зону',
    'Editar zona': 'Редактировать зону',
    'Eliminar zona': 'Удалить зону',
    'Zona eliminada.': 'Зона удалена.',
    'Capacidad': 'Вместимость',
    'Meta': 'Цель',
    'Color servicio': 'Цвет услуги',
    'Color zona': 'Цвет зоны',
    'Color premio': 'Цвет бонуса',
    'Requiere zona': 'Нужна зона',
    'Con zona': 'С зоной',
    'Zonas permitidas': 'Разрешенные зоны',
    'Descripcion': 'Описание',
    'Duracion min': 'Длительность, мин',
    'Precio': 'Цена',
    'Tipo': 'Тип',
    'Cabina': 'Кабина',
    'Mesa': 'Стол',
    'Lavacabezas': 'Мойка',
    'Maquillaje': 'Макияж',
    'Otro': 'Другое',
    'Activa': 'Активна',
    'Inactiva': 'Неактивна',
    'Editar premio': 'Редактировать бонус',
    'Descuento %': 'Скидка %',
    'Buscar cliente': 'Найти клиента',
    'Nombre, telefono o email': 'Имя, телефон или email',
    'No hay clientes todavia.': 'Клиентов пока нет.',
    'No hay clientes para esta busqueda.': 'По этому поиску клиентов нет.',
    'Eliminar cliente': 'Удалить клиента',
    'Cliente eliminado.': 'Клиент удален.',
    'Actividad': 'Активность',
    'Ultima visita': 'Последний визит',
    'Proxima cita': 'Следующая запись',
    'Para proximo premio': 'До следующего бонуса',
    'Servicios favoritos': 'Любимые услуги',
    'Empleados habituales': 'Постоянные сотрудники',
    'Clientes referidos': 'Приглашенные клиенты',
    'Historial de reservas': 'История записей',
    'Piramide de recomendaciones': 'Пирамида рекомендаций',
    'Historial visual': 'История фото',
    'Sin servicio': 'Без услуги',
    'Sin empleado': 'Без сотрудника',
    'Sin referidos.': 'Нет приглашенных.',
  };
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
