// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'main.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BookingAdapter extends TypeAdapter<Booking> {
  @override
  final int typeId = 0;

  @override
  Booking read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Booking(
      name: fields[0] as String,
      contact: fields[1] as String,
      ticketType: fields[2] as String,
      isPaid: fields[3] as bool,
      isTicketGiven: fields[4] as bool,
      photoPath: fields[5] as String?,
      routeFrom: fields[6] as String?,
      routeTo: fields[7] as String?,
      date: fields[8] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Booking obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.contact)
      ..writeByte(2)
      ..write(obj.ticketType)
      ..writeByte(3)
      ..write(obj.isPaid)
      ..writeByte(4)
      ..write(obj.isTicketGiven)
      ..writeByte(5)
      ..write(obj.photoPath)
      ..writeByte(6)
      ..write(obj.routeFrom)
      ..writeByte(7)
      ..write(obj.routeTo)
      ..writeByte(8)
      ..write(obj.date);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BookingAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
