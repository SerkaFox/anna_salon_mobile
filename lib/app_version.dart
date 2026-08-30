const appVersionName = '0.1.47';
const appVersionBuild = 48;

const appChangeLog = <AppChangeLogEntry>[
  AppChangeLogEntry(
    version: '0.1.47',
    build: 48,
    changesRu: [
      'В карточке оплаченного заказа добавлена кнопка «Фактура на предоплату».',
      'Фактура создаётся только на внесённую сумму и позволяет указать данные фактического плательщика.',
      'Данные плательщика не изменяют имя и профиль клиентки.',
    ],
    changesEs: [
      'La reserva con señal pagada incluye el botón «Factura del prepago».',
      'La factura usa solo el importe anticipado y permite indicar los datos del pagador real.',
      'Los datos del pagador no modifican el nombre ni el perfil de la clienta.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.46',
    build: 47,
    changesRu: [
      'После успешной предоплаты повторная ссылка блокируется, чтобы не списать деньги дважды.',
      'В карточке заказа показывается понятное объяснение, что предоплата уже внесена.',
    ],
    changesEs: [
      'Después de un prepago correcto se bloquea otro enlace para evitar un cobro duplicado.',
      'La ficha de la reserva explica claramente que el prepago ya está realizado.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.45',
    build: 46,
    changesRu: [
      'Клиент видит расходы только за текущую неделю и месяц; сумма за всю историю скрыта.',
      'Автоматические награды убраны из клиентского кабинета, скидку назначает салон.',
      'В клиентской записи добавлен поиск услуги по нескольким буквам.',
      'Клиенты без предоплаты получают подтверждённую запись без платёжного окна и автоотмены.',
      'Сотрудник видит только свою карточку и личный заработок, а также может открыть и закрыть кассу без общей выручки.',
    ],
    changesEs: [
      'El cliente ve el gasto de la semana y del mes, sin el total histórico.',
      'Los premios automáticos se retiraron del portal del cliente; el salón decide los descuentos.',
      'La reserva del cliente permite buscar servicios escribiendo varias letras.',
      'Los clientes exentos de prepago reciben la reserva confirmada sin ventana de pago ni cancelación automática.',
      'El empleado solo ve su ficha y sus ganancias, y puede usar y cerrar la caja sin ver la facturación total.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.44',
    build: 45,
    changesRu: [
      'Добавлены отдельные переключатели для каждого вида уведомлений приложения.',
      'Можно независимо включать новые записи, отмены, переносы, смену мастера, предоплаты и напоминания за 24 и 2 часа.',
      'При нажатии на уведомление приложение открывает нужную запись в календаре.',
    ],
    changesEs: [
      'Se añadieron interruptores independientes para cada tipo de aviso de la aplicación.',
      'Se pueden configurar nuevas reservas, cancelaciones, cambios, especialista, prepagos y recordatorios de 24 y 2 horas.',
      'Al pulsar un aviso, la aplicación abre la reserva correspondiente en el calendario.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.43',
    build: 44,
    changesRu: [
      'Исправлены перепутанные имена и WhatsApp-телефоны клиентов из старого импорта.',
      'Список клиентов загружается страницами по 10 записей и больше не подвешивает приложение.',
      'Поиск, фильтры и сортировка клиентов работают по всей базе на сервере.',
      'Сайт напоминает новым клиентам указать настоящее имя и не принимает номер телефона вместо имени.',
    ],
    changesEs: [
      'Se corrigieron nombres y teléfonos de WhatsApp intercambiados en una importación anterior.',
      'La lista de clientes carga páginas de 10 registros para evitar bloqueos.',
      'La búsqueda, los filtros y el orden se aplican a toda la base de datos en el servidor.',
      'La web recuerda a los clientes nuevos que indiquen su nombre y no acepta un teléfono como nombre.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.42',
    build: 43,
    changesRu: [
      'Интерфейс управления уведомлениями WhatsApp полностью переведён; тексты шаблонов сохранены на испанском.',
      'В настройках появился отдельный раздел уведомлений приложения с кнопками включения и выключения.',
      'Владелец и администратор получают уведомления обо всех новых записях, сотрудники — о своих.',
    ],
    changesEs: [
      'La interfaz de gestión de WhatsApp sigue el idioma de la aplicación; los textos de las plantillas permanecen en español.',
      'Los ajustes incluyen una sección separada para activar o desactivar los avisos de la aplicación.',
      'Propietario y administrador reciben avisos de todas las reservas nuevas; cada empleado recibe las suyas.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.41',
    build: 42,
    changesRu: [
      'Сотрудники сами могут взять день отпуска и поставить себе обед прямо в приложении.',
      'Штриховку нерабочего времени в календаре можно снять одним нажатием, чтобы поработать сверх графика.',
      'Касса открыта для сотрудников: можно выставлять счета и закрывать кассу, но общую выручку и данные Stripe видит только Анна.',
    ],
    changesEs: [
      'Los empleados ya pueden pedir su propio día de vacaciones y poner su hora de comida desde la app.',
      'Se puede liberar de un toque el horario bloqueado del calendario para trabajar fuera de turno.',
      'La caja está disponible para el equipo: pueden facturar y cerrar caja, pero el total del día y Stripe solo los ve Anna.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.40',
    build: 41,
    changesRu: [
      'В настройках появился статус уведомлений и кнопка их включения.',
      'Время услуги можно не только увеличить, но и сократить шагом 15 минут; минимум — 15 минут.',
    ],
    changesEs: [
      'Los ajustes muestran el estado de los avisos y permiten activarlos.',
      'La duración del servicio se puede aumentar o reducir en pasos de 15 minutos; mínimo 15 minutos.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.39',
    build: 40,
    changesRu: [
      'Уведомления работнику о новых записях с именем клиента, датой, временем и услугами.',
      'Нажатие на уведомление открывает нужную запись в календаре.',
    ],
    changesEs: [
      'Avisos al empleado sobre nuevas reservas con cliente, fecha, hora y servicios.',
      'Al pulsar el aviso se abre la reserva correspondiente en el calendario.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.38',
    build: 39,
    changesRu: [
      'После установки Android показывает понятную кнопку «Открыть».',
    ],
    changesEs: [
      'Android muestra un boton claro para abrir la aplicacion tras instalar.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.37',
    build: 38,
    changesRu: [
      'Контрольный выпуск для системного возврата после установки.',
    ],
    changesEs: [
      'Version de comprobacion del retorno tras la instalacion.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.36',
    build: 37,
    changesRu: [
      'Системный установщик возвращает пользователя прямо в приложение.',
    ],
    changesEs: [
      'El instalador del sistema devuelve al usuario directamente a la aplicacion.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.35',
    build: 36,
    changesRu: [
      'Перезапуск после обновления адаптирован для ограничений Android 14–16.',
    ],
    changesEs: [
      'Reinicio tras actualizar adaptado a las restricciones de Android 14–16.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.34',
    build: 35,
    changesRu: [
      'Установка продолжается автоматически после выдачи разрешения.',
      'Приложение повторно запускается после успешного обновления.',
    ],
    changesEs: [
      'La instalacion continua automaticamente despues del permiso.',
      'La aplicacion vuelve a abrirse despues de actualizarse.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.33',
    build: 34,
    changesRu: [
      'Шкала календаря продлена до 21:00.',
    ],
    changesEs: [
      'La escala del calendario se amplio hasta las 21:00.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.32',
    build: 33,
    changesRu: [
      'Автоматическая проверка обновлений при запуске.',
      'Защищённое скачивание APK с проверкой SHA-256.',
      'Установка обновлений и ручная проверка из настроек.',
    ],
    changesEs: [
      'Comprobacion automatica de actualizaciones al iniciar.',
      'Descarga protegida del APK con verificacion SHA-256.',
      'Instalacion y comprobacion manual desde los ajustes.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.31',
    build: 32,
    changesRu: [
      'Поиск клиентов, услуг и сотрудников при добавлении в лист ожидания.',
      'Текущая версия и история изменений добавлены в настройки.',
    ],
    changesEs: [
      'Busqueda de clientes, servicios y empleados al anadir a la lista de espera.',
      'Version actual e historial de cambios en los ajustes.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.30',
    build: 31,
    changesRu: [
      'Анна может создавать записи вручную вне рабочего графика.',
      'Добавление в лист ожидания из приложения.',
      'Дата или период ожидания, желаемое время и комментарий.',
    ],
    changesEs: [
      'Reservas manuales fuera del horario de trabajo.',
      'Alta en la lista de espera desde la aplicacion.',
      'Fecha o periodo, horario deseado y comentario.',
    ],
  ),
  AppChangeLogEntry(
    version: '0.1.29',
    build: 30,
    changesRu: [
      'Красная линия текущего времени в календаре.',
      'Чёрные деления календаря по 15 минут.',
      'Поиск услуг, отпускные сотрудников и серый цвет оплаченных заказов.',
    ],
    changesEs: [
      'Linea roja de la hora actual en el calendario.',
      'Divisiones negras cada 15 minutos.',
      'Busqueda de servicios, vacaciones y reservas pagadas en gris.',
    ],
  ),
];

class AppChangeLogEntry {
  const AppChangeLogEntry({
    required this.version,
    required this.build,
    required this.changesRu,
    required this.changesEs,
  });

  final String version;
  final int build;
  final List<String> changesRu;
  final List<String> changesEs;
}
