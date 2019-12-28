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
  TypeChecker fieldAnnotation = TypeChecker.fromRuntime(annotation.Field);

  @override
  FutureOr<String> generateForAnnotatedElement(
      Element element, ConstantReader annotation, BuildStep buildStep) {
    name = '${element.name}Bloc';
    this.element = element;
    extend = refer('BlocBase');
    _declareField();
    _constructor();
    _methodSetEntity();
    _methodInserOrUpdate();
    _methodDispose();
    _methodDelete();
    // var generateClass = GenerateBlocClass(element.name);
    // var fieldAnnotation = TypeChecker.fromRuntime(Field);
    // for (var field in (element as ClassElement).fields) {
    //   generateClass.declareField(field.type.name, field.name,
    //       persistField: fieldAnnotation.hasAnnotationOfExact(field));
    // }
    // return generateClass.build();
    return "import 'package:bloc_pattern/bloc_pattern.dart';"
            "import 'package:rxdart/rxdart.dart';"
            "import '${element.name.toLowerCase()}.entity.dart';" 
            "import '${element.name.toLowerCase()}.repository.dart';" +
        build();
  }

  void _declareField() {
    declareField(refer('String'), '_documentId');
    declareField(refer('var'), '_repository',
        assignment: Code('${element.name}Repository()'));
    declareMethod('list',
        returns: refer('Stream<List<$entityClass>>'),
        lambda: true,
        type: MethodType.getter,
        body: Code('_repository.list()'));
    elementAsClass.fields.forEach((field) {
      declareField(refer(field.type.name), '_${field.name}');
      declareField(refer('var'), '_${field.name}Controller',
          assignment: Code('BehaviorSubject<${field.type.name}>(sync: true)'));
      declareMethod('out${field.name}',
          returns: refer('Stream<${field.type.name}>'),
          type: MethodType.getter,
          lambda: true,
          body: Code('_${field.name}Controller.stream'));
      declareMethod('set${field.name}',
        returns: refer('void'),
          // type: MethodType.setter,
          requiredParameters: [
            Parameter((b) => b
              ..name = 'value'
              ..type = refer(field.type.name))
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
              ..type = refer(entityClass))
          ],
          body: entityCode.build());
    }
  }

  void _methodInserOrUpdate() {
    var insertOrUpdateCode = BlockBuilder();
    elementAsClass.fields.forEach((field) {
      if (fieldAnnotation.hasAnnotationOfExact(field)) {
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
