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
      ? 'Введите логин, телефон или email. Временный доступ придёт в WhatsApp и на email, если они указаны.'
      : 'Introduce usuario, teléfono o email. Enviaremos el acceso temporal por WhatsApp y email si están disponibles.';
  String get sendTemporaryAccess =>
      isRussian ? 'Отправить временный доступ' : 'Enviar acceso temporal';
  String get recoverySent => isRussian
      ? 'Если данные совпали, временный логин и пароль уже отправлены на доступные контакты.'
      : 'Si los datos coinciden, ya hemos enviado el usuario y la contraseña temporal a los contactos disponibles.';
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
  String get lightTheme => isRussian ? 'Белая тема' : 'Tema blanco';
  String get lightThemeHelp => isRussian
      ? 'Чисто белый фон и тёмный текст.'
      : 'Fondo blanco puro y texto oscuro.';
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
    'Fuera del horario (manual)': 'Вне графика (вручную)',
    'Hora elegida manualmente por el personal. No esta disponible para clientes.':
        'Время выбрано сотрудником вручную. Клиентам оно недоступно.',
    'Editar horario': 'Изменить график',
    'Horario de trabajo': 'Рабочий график',
    'Guardar horario': 'Сохранить график',
    'Horario guardado.': 'График сохранен.',
    'Dia libre': 'Выходной',
    'Trabaja': 'Работает',
    'Desde': 'С',
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
    'Sin prepago · pago en el salon':
        'Предоплата не требуется · оплата на месте',
    'Usar para clientes que no pueden pagar mediante el enlace.':
        'Для клиентов, которые не могут оплатить по ссылке.',
    'Requerir prepago': 'Требовать предоплату',
    'Se enviara un enlace de Stripe. Plazo: 30 minutos.':
        'Ссылка Stripe отправится автоматически. Срок оплаты — 30 минут.',
    'Sin enlace · la cita queda confirmada y se paga en el salon.':
        'Без ссылки · запись сразу подтверждена, оплата в салоне.',
    'Prepago': 'Предоплата',
    'Limite de prepago': 'Оплатить до',
    'No requerir prepago · pago en el salon':
        'Не требовать предоплату · оплата на месте',
    'Enviar enlace de prepago': 'Отправить ссылку на предоплату',
    'Prepago ya realizado': 'Предоплата уже внесена',
    'No se puede enviar otro enlace para evitar un cobro duplicado.':
        'Повторную ссылку нельзя отправить, чтобы не списать деньги дважды.',
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
    'Salon': 'Салон',
    'Mi trabajo': 'Моя работа',
    'Datos, servicios, comision, estadisticas y color.':
        'Данные, услуги, комиссия, статистика и цвет.',
    'Datos propios, servicios que realizas y estadisticas.':
        'Личные данные, ваши услуги и статистика.',
    'Servicios y zonas': 'Услуги и зоны',
    'Servicios, precios, duracion, colores y recursos.':
        'Услуги, цены, длительность, цвета и ресурсы.',
    'Selecciona primero un servicio.': 'Сначала выберите услугу.',
    'Selecciona un empleado.': 'Выберите сотрудника.',
    'Este empleado no realiza el servicio seleccionado.':
        'Этот сотрудник не выполняет выбранную услугу.',
    'Selecciona una zona para este servicio.': 'Выберите зону для этой услуги.',
    'La zona seleccionada no esta permitida para este servicio.':
        'Выбранная зона не разрешена для этой услуги.',
    'Selecciona un horario disponible.': 'Выберите доступное время.',
    'Selecciona un cliente.': 'Выберите клиента.',
    'Visitas hechas': 'Сделано визитов',
    'Gastado total': 'Потрачено всего',
    'Clientes traidos': 'Приведено клиентов',
    'Nuevo cliente': 'Новый клиент',
    'Editar cliente': 'Редактировать клиента',
    'Fecha de nacimiento': 'Дата рождения',
    'Acceso cliente': 'Доступ клиента',
    'Generar acceso': 'Создать доступ',
    'Usuario para cliente': 'Пользователь клиента',
    'Contraseña inicial': 'Первоначальный пароль',
    'Nueva contraseña': 'Новый пароль',
    'Acceso cliente creado': 'Доступ клиента создан',
    'Listo': 'Готово',
    'Este cliente no tiene telefono valido.':
        'У клиента нет корректного телефона.',
    'Hoy': 'Сегодня',
    'Sin reservas': 'Нет записей',
    'Nuevo en calendario': 'Новое в календаре',
    'Crear reserva con este empleado y horario.':
        'Создать запись с этим сотрудником на это время.',
    'Nueva pausa / bloqueo': 'Новая пауза / блок',
    'Bloquear este tramo en el calendario.':
        'Заблокировать этот интервал в календаре.',
    'Bloqueo': 'Блок',
    'Motivo': 'Причина',
    'Inicio': 'Начало',
    'Fin': 'Конец',
    'Este bloque pertenece al horario del empleado. Editalo desde la configuracion del horario del empleado.':
        'Этот блок относится к графику сотрудника. Редактируйте его в настройках графика сотрудника.',
    'Editar': 'Редактировать',
    'Borrar': 'Удалить',
    'Creado': 'Создан',
    'Foto': 'Фото',
    'Cerrar': 'Закрыть',
    'Ver empleados': 'Показать сотрудников',
    'Ver dias': 'Показать дни',
    'Anterior': 'Назад',
    'Siguiente': 'Вперед',
    'Todos': 'Все',
    'Turno': 'Смена',
    'Sin turno': 'Без смены',
    'Fuera del horario laboral': 'Вне рабочего графика',
    'No se encontro el identificador del bloqueo.':
        'Не найден идентификатор блока.',
    'Borrar bloqueo': 'Удалить блок',
    'Editar bloqueo': 'Редактировать блок',
    'Selecciona empleado': 'Выберите сотрудника',
    'Selecciona un motivo': 'Выберите причину',
    'Recurrencia': 'Повтор',
    'Hasta': 'До',
    'Crear bloqueo': 'Создать блок',
    'Selecciona al menos una zona para este servicio.':
        'Выберите хотя бы одну зону для этой услуги.',
    'Selecciona un servicio valido.': 'Выберите корректную услугу.',
    'Selecciona un empleado valido.': 'Выберите корректного сотрудника.',
    'Pausa': 'Пауза',
    'Seleccionar': 'Выбрать',
    'Zona automatica': 'Автоматическая зона',
    'Reprogramar': 'Перенести',
    'Comprobar y reprogramar': 'Проверить и перенести',
    'Estado': 'Статус',
    'Origen': 'Источник',
    'Precio': 'Цена',
    'Duracion': 'Длительность',
    'Guardar cambios': 'Сохранить изменения',
    'Editar reserva': 'Редактировать запись',
    'Pendiente': 'Ожидает',
    'Confirmada': 'Подтверждена',
    'Completada': 'Завершена',
    'Cancelada': 'Отменена',
    'No asistio': 'Не пришел',
    'Manual': 'Вручную',
    'Confirmar': 'Подтвердить',
    'Caja': 'Касса',
    'Cobros, documentos, caja del dia y cierres.':
        'Платежи, документы, касса дня и закрытия.',
    'Sin pagos todavia.': 'Платежей пока нет.',
    'Documentos pendientes': 'Документы с остатком',
    'Cerrar caja': 'Закрыть кассу',
    'Cierre guardado.': 'Закрытие кассы сохранено.',
    'Cobro rapido': 'Быстрый платеж',
    'Recibo': 'Чек',
    'Factura': 'Фактура',
    'Anadir linea': 'Добавить строку',
    'Añadir linea': 'Добавить строку',
    'Registrar pago': 'Зарегистрировать платеж',
    'Devolucion': 'Возврат',
    'Efectivo': 'Наличные',
    'Tarjeta': 'Карта',
    'Transferencia': 'Перевод',
    'Importe': 'Сумма',
    'Metodo': 'Способ',
    'Referencia': 'Ссылка',
    'Concepto': 'Позиция',
    'Cantidad': 'Количество',
    'Precio unitario': 'Цена за единицу',
    'Importe manual': 'Своя сумма',
    'Saldo pendiente': 'Остаток',
    'Pagos del dia': 'Платежи дня',
    'Total del dia': 'Итого за день',
    'Abrir documento': 'Открыть документ',
    'Crear recibo': 'Создать чек',
    'Crear factura': 'Создать фактуру',
    'Pago': 'Платеж',
    'Concepto e importe': 'Позиция и сумма',
    'Sin documentos pendientes.': 'Документов с остатком нет.',
    'Todavia no hay fotos guardadas para este cliente.':
        'Для этого клиента пока нет сохраненных фото.',
    'Sin datos adicionales.': 'Нет дополнительных данных.',
    'Ya disponible': 'Уже доступно',
    'visitas': 'визитов',
    'Solo este dia': 'Только этот день',
    'Cada semana este dia': 'Каждую неделю в этот день',
    'Todos los dias laborales': 'Все рабочие дни',
    'Reserva reprogramada.': 'Запись перенесена.',
    'Reserva reprogramada. Actualiza el calendario si no aparece en el nuevo horario.':
        'Запись перенесена. Обновите календарь, если она не появилась в новом времени.',
    'Reserva actualizada.': 'Запись обновлена.',
    'referidos': 'приглашенных',
    'Concepto manual': 'Своя позиция',
    'Servicio extra': 'Доп. услуга',
    'Cobrar': 'Оплатить',
    'Cobro y documento': 'Оплата и документ',
    'Documento cobrado completo.': 'Документ оплачен полностью.',
    'Enviar documento': 'Отправить документ',
    'Enviar por email': 'Отправить на email',
    'Documento enviado por email.': 'Документ отправлен на email.',
    'Pagado': 'Оплачено',
    'Total': 'Итого',
    'Falta por pagar': 'Осталось оплатить',
    'Importe a registrar': 'Сумма платежа',
    'Introduce importe.': 'Введите сумму.',
    'Por defecto se rellena con el saldo pendiente.':
        'По умолчанию подставляется остаток к оплате.',
    'Puedes registrar varios pagos hasta completar el saldo pendiente.':
        'Можно зарегистрировать несколько платежей, пока остаток не будет закрыт.',
    'Puedes cobrar una parte ahora y el resto despues con otro metodo.':
        'Можно принять часть сейчас, а остаток другим способом.',
    'Falta email o telefono de WhatsApp para enviar el documento.':
        'Добавьте email или телефон WhatsApp, чтобы отправить документ.',
    'Elige como enviar el documento al cliente.':
        'Выберите, как отправить документ клиенту.',
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
