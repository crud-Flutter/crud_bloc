import 'dart:async';

import 'package:analyzer/dart/element/element.dart';
import 'package:build/src/builder/build_step.dart';
import 'package:code_builder/code_builder.dart';
import 'package:crud_generator/crud_generator.dart';
import 'package:flutter_persistence_api/flutter_persistence_api.dart'
    as annotation;
import 'package:source_gen/source_gen.dart';

class BlocGenerator
    extends GenerateEntityClassForAnnotation<annotation.Entity> {
  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    init();
    name = '${element.name}Bloc';
    this.element = element;
    extend = refer('BlocBase');
    addImportPackage('package:bloc_pattern/bloc_pattern.dart');
    addImportPackage('${element.name.toLowerCase()}.entity.dart');
    _declareField();
    _constructor();
    _methodSetEntity();
    _methodInserOrUpdate();
    _methodDispose();
    _methodDelete();
    _methodListManyToOne();
    _methodListOneToMany();
    _methodUpdateManyToOneByDisplayField();
    return build();
  }

  void _declareField() {
    addImportPackage('${element.name.toLowerCase()}.repository.dart');
    addImportPackage('package:rxdart/rxdart.dart');
    declareField(refer('String'), '_documentId');
    declareField(refer('var'), '_repository',
        assignment: Code('${element.name}Repository()'));
    declareMethod('list',
        returns: refer('Stream<List<$entityClass>>'),
        lambda: true,
        type: MethodType.getter,
        body: Code('_repository.list()'));
    elementAsClass.fields.forEach((field) {
      var type = field.type.name;
      var name = '_${field.name}';
      if (isManyToOneField(field)) {
        addImportPackage(
            '../${field.type.name.toLowerCase()}/${field.type.name.toLowerCase()}.dart');
      } else if (isOneToManyField(field)) {
        type += '<${getGenericTypes(field.type).first.name}>';
        addImportPackage(
            '../${getGenericTypes(field.type).first.name.toLowerCase()}/'
            '${getGenericTypes(field.type).first.name.toLowerCase()}.dart');
      }
      declareField(refer(type), name);
      declareField(refer('var'), '_${field.name}Controller',
          assignment: Code('BehaviorSubject<$type>(' +
              (['DateTime', 'Date', 'Date'].contains(field.type.name)
                  ? 'sync: true'
                  : '') +
              ')'));
      declareMethod('out${field.name}',
          returns: refer('Stream<$type>'),
          type: MethodType.getter,
          lambda: true,
          body: Code('_${field.name}Controller.stream'));
      declareMethod('set${field.name}',
          returns: refer('void'),
          // type: MethodType.setter,
          requiredParameters: [
            Parameter((b) => b
              ..name = 'value'
              ..type = refer(type))
          ],
          lambda: true,
          body: Code('_${field.name}Controller.sink.add(value)'));
    });
  }

  void _constructor() {
    var constructorVar = BlockBuilder();
    elementAsClass.fields.forEach((field) {
      constructorVar.statements.add(Code(
          '_${field.name}Controller.listen((value) => _${field.name} = value);'));
    });
    if (constructorVar.statements.length > 0) {
      declareConstructor(body: constructorVar.build());
    }
  }

  void _methodSetEntity() {
    var entityCode = BlockBuilder();
    elementAsClass.fields.forEach((field) {
      entityCode.statements
          .add(Code('set${field.name}(${entityInstance}.${field.name});'));
    });
    if (entityCode.statements.isNotEmpty) {
      entityCode.statements
          .insert(0, Code('_documentId = $entityInstance.documentId();'));
      declareMethod('set$entityClass',
          requiredParameters: [
            Parameter((b) => b
              ..name = entityInstance
              ..type = refer(
                  entityClass, '${element.name.toLowerCase()}.entity.dart'))
          ],
          body: entityCode.build());
    }
  }

  void _methodInserOrUpdate() {
    var insertOrUpdateCode = BlockBuilder();
    elementAsClass.fields.forEach((field) {
      if (isFieldPersist(field)) {
        insertOrUpdateCode.statements
            .add(Code('..${field.name} = _${field.name}'));
      }
    });
    if (insertOrUpdateCode.statements.isNotEmpty) {
      insertOrUpdateCode.statements
          .insert(0, Code('var $entityInstance = $entityClass()'));
      insertOrUpdateCode.statements.add(Code(';'));
      insertOrUpdateCode.statements
          .add(Code('if (_documentId?.isEmpty ?? true) {'));
      insertOrUpdateCode.statements
          .add(Code('return _repository.add($entityInstance);'));
      insertOrUpdateCode.statements.add(Code('} else {'));
      insertOrUpdateCode.statements.add(
          Code('return _repository.update(_documentId, $entityInstance);'));
      insertOrUpdateCode.statements.add(Code('}'));
    }
    declareMethod('insertOrUpdate',
        returns: refer('Future<dynamic>'), body: insertOrUpdateCode.build());
  }

  void _methodDelete() {
    declareMethod('delete',
        returns: refer('Future<void>'),
        requiredParameters: [
          Parameter((b) => b
            ..name = 'documentId'
            ..type = refer('String'))
        ],
        lambda: true,
        body: Code('_repository.delete(documentId)'));
  }

  void _methodListManyToOne() {
    elementAsClass.fields.forEach((field) {
      if (isManyToOneField(field)) {
        addImportPackage(
            '../${field.type.name.toLowerCase()}/${field.type.name.toLowerCase()}.repository.dart');
        addImportPackage(
            '../${field.type.name.toLowerCase()}/${field.type.name.toLowerCase()}.entity.dart');
        declareMethod('list${field.type.name}',
            returns: refer('Stream<List<${field.type.name}Entity>>'),
            lambda: true,
            body: Code('${field.type.name}Repository().list()'));
      }
    });
  }

  void _methodListOneToMany() {
    elementAsClass.fields.forEach((field) {
      if (isOneToManyField(field)) {
        addImportPackage(
            '../${getGenericTypes(field.type).first.name.toLowerCase()}'
            '/${getGenericTypes(field.type).first.name.toLowerCase()}.repository.dart');
        addImportPackage(
            '../${getGenericTypes(field.type).first.name.toLowerCase()}'
            '/${getGenericTypes(field.type).first.name.toLowerCase()}.entity.dart');
        declareMethod('list${getGenericTypes(field.type).first}',
            returns: refer(
                'Stream<List<${getGenericTypes(field.type).first}Entity>>'),
            lambda: true,
            body: Code(
                '${getGenericTypes(field.type).first}Repository().list()'));
      }
    });
  }

  void _methodUpdateManyToOneByDisplayField() {
    elementAsClass.fields.forEach((field) {
      if (isManyToOneField(field)) {
        var displayField = getDisplayField(annotation.ManyToOne, field);
        declareMethod('update${field.type.name}by$displayField',
            requiredParameters: [
              Parameter((b) => b
                ..name = '${field.name}Entity'
                ..type = refer('${field.type.name}Entity'))
            ],
            body: Block((b) => b
              ..statements.addAll([
                Code(
                    'if (${field.name}Entity.$displayField == _${field.name}?.$displayField) {'),
                Code('set${field.name}(${field.name}Entity);'),
                Code('}')
              ])));
      }
    });
  }

  void _methodDispose() {
    var disposeCode = BlockBuilder();
    elementAsClass.fields.forEach((field) {
      disposeCode.statements.add(Code('_${field.name}Controller.close();'));
    });
    if (disposeCode.statements.isNotEmpty) {
      disposeCode.statements.add(Code('super.dispose();'));
      declareMethod('dispose', body: disposeCode.build());
    }
  }
}
