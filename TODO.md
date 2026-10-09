# TODO

## Фильтровать зоны по выбранному мастеру в форме редактирования записи

**Статус:** сделано, 2026-10-10
**Заведено:** 2026-10-08, по жалобе Ани

### Что происходит

Аня не смогла перенести педикюр Магдалены (11 дек) с Hanna на Daniela. В «Editar reserva»
она поменяла **Zona → zona B**, но **Empleado оставила Hanna**. Результат: красная плашка
`Este empleado no trabaja en la zona seleccionada` и пустой список «Horas disponibles».

Бэкенд отработал правильно — зоны у мастеров закреплены жёстко:

| Мастер            | Зоны           |
|-------------------|----------------|
| Hanna Briukhovets | zona A, zona C |
| Daniela Mancilla  | zona B         |
| Elena Shishkova   | zona C         |

Hanna в zona B свободных слотов не имеет и иметь не может. Проблема чисто в UX: приложение
даёт выбрать заведомо невозможную комбинацию и сообщает об этом только плашкой внизу формы.

### Что сделать

Всё в `lib/screens/calendar_screen.dart`.

1. **Подхватить зоны мастера.** В `_BookingEditReferences._options` (~строка 3829)
   `allowedZoneIds` читается по ключам `['allowed_zone_ids', 'allowed_zones', 'zones']`.
   У записи сотрудника API отдаёт поле **`zone_ids`** (см. `EmployeeSerializer`,
   `mobile_api/serializers.py:360` в бэкенде) — его в списке нет, поэтому у `_EditOption`
   сотрудника `allowedZoneIds` сейчас всегда пустой. Добавить `'zone_ids'` в список ключей.

2. **Пересечь зоны услуги с зонами мастера.** В `build` (~строки 3465-3467):

   ```dart
   final zoneOptions = selectedService?.requiresZone == true
       ? refs.zonesForService(selectedService!)
       : const <_EditOption>[];
   ```

   Добавить в `_BookingEditReferences` метод `zonesForEmployee(employee)` и, если мастер
   выбран, оставлять только пересечение. Если у мастера зон не проставлено вообще
   (`allowedZoneIds.isEmpty`) — не фильтровать, как сделано в `employeesForService`.

3. **Сбрасывать зону при смене мастера.** `_changeEmployee` (~строка 3298) сейчас трогает
   `_zoneId` только когда мастер не умеет выбранную услугу. Надо: если текущая `_zoneId`
   не входит в зоны нового мастера — сбросить в `null` («Zona automatica»), а если у мастера
   подходящая зона ровно одна — подставить её сразу. По аналогии с `_changeService`
   (~строка 3274), который уже сбрасывает зону через `zoneAllowedForService`.

### Проверка

Открыть запись #11915 (Magdalena Panasewicz, 11 дек, Pedicura Con Esmaltado Normal,
Hanna / zona A) → сменить Empleado на Daniela Mancilla → zona B должна подставиться сама,
в «Horas disponibles» должен появиться слот **10:00**. Выбрать Hanna + zona B должно быть
невозможно в принципе.

Данных на бэкенде хватает, менять там ничего не нужно.
