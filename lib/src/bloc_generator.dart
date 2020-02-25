import 'package:code_builder/code_builder.dart';
import 'package:crud_generator/crud_generator.dart';
import 'package:flutter_persistence_api/flutter_persistence_api.dart'
    as annotation;

class BlocGenerator
    extends GenerateEntityClassForAnnotation<annotation.Entity> {
  @override
  String generateName() => '${element.name}${manyToManyPosFix}Bloc';

  @override
  void optionalClassInfo() {
    extend = refer('BlocBase');
    addImportPackage('package:bloc_pattern/bloc_pattern.dart');
    if (!manyToMany) {
      addImportPackage('${element.name.toLowerCase()}.entity.dart');
    }
  }

  @override
  void generateFields() {
    declareField(refer(entityClass), '_$entityInstance');
    declareMethod(entityInstance,
        type: MethodType.getter,
        returns: refer(entityClass),
        lambda: true,
        body: Code('_$entityInstance'));

    if (!manyToMany) {
      addImportPackage('${element.name.toLowerCase()}.repository.dart');
    }
    // addImportPackage('package:rxdart/subjects.dart');
    if (manyToMany) {
      declareField(refer('var'), '_repository');
    } else {
      declareField(refer('var'), '_repository',
          assignment: Code('${element.name}${manyToManyPosFix}Repository()'));
    }
    declareMethod('list',
        returns:
            refer('Stream<List<${element.name}${manyToManyPosFix}Entity>>'),
        lambda: true,
        type: MethodType.getter,
        body: Code('_repository.list()'));
    elementAsClass.fields.forEach((field) {
      var type = field.type.name;
      var body = '_$entityInstance.${field.name} = value';
      var lambda = true;
      if (isManyToOneField(field)) {
        addImportPackage('package:rxdart/streams.dart');
        type += 'Entity';
        declareField(refer('Stream<List<${field.type.name}Entity>>'),
            'list${field.name}');
      } else if (isOneToManyField(field)) {
        addImportPackage(
            '../${getGenericTypes(field.type).first.name.toLowerCase()}'
            '/${getGenericTypes(field.type).first.name.toLowerCase()}.entity.dart');
        addImportPackage(
            '../${getGenericTypes(field.type).first.name.toLowerCase()}'
            '/${getGenericTypes(field.type).first.name.toLowerCase()}.repository.dart');
        type += '<${getGenericTypes(field.type).first.name}Entity>';
        body += ';';
        lambda = false;
        declareField(refer('Stream<$type>'), 'list${field.name}',
            assignment: Code(
                '${getGenericTypes(field.type).first.name}Repository().list()'));
      } else if (isManyToManyField(field)) {
        type += '<${getGenericTypes(field.type).first.name}ManyToManyEntity>';
        addImportPackage(
            '${getGenericTypes(field.type).first.name.toLowerCase()}.dart');
      }
      // declareField(refer('var'), '_${field.name}Controller',
      //     assignment: Code('BehaviorSubject<$type>(' +
      //         (['DateTime', 'Date', 'Date'].contains(field.type.name)
      //             ? 'sync: true'
      //             : '') +
      //         ')'));
      // declareMethod('out${field.name}',
      //     returns: refer('Stream<$type>'),
      //     type: MethodType.getter,
      //     lambda: true,
      //     body: Code('_${field.name}Controller.stream'));
      declareMethod('set${field.name}',
          returns: refer('void'),
          requiredParameters: [
            Parameter((b) => b
              ..name = 'value'
              ..type = refer(type))
          ],
          lambda: lambda,
          body: Code(body));
    });
  }

  @override
  void generateConstructors() {}

  @override
  void generateMethods() {
    _methodAddOneToMany();
    _methodAddManyToMany();
    _methodSetEntity();
    _methodInserOrUpdate();
    _methodDispose();
    _methodDelete();
    _methodListManyToOne();
    _methodListOneToMany();
    _methodHasOneToMany();
    _methodUpdateManyToOneByDisplayField();
    _methodRemoveOneToMany();
  }

  void _methodSetEntity() {
    var setEntityCode =
        StringBuffer('_$entityInstance = $entityInstance ?? $entityClass();');
    elementAsClass.fields.forEach((field) {
      if (isManyToOneField(field)) {
        addImportPackage('package:rxdart/transformers.dart');
        var displayField = getDisplayField(annotation.ManyToOne, field);
        setEntityCode.writeln('''list${field.name} = RetryStream(() =>
          ${field.type.name}Repository().list()
          ).doOnData((${field.name}List) {
            ${field.name}List.forEach((${field.name}) {
              if (_$entityInstance.${field.name}.$displayField == ${field.name}.$displayField) {
                  _$entityInstance.${field.name} = ${field.name};
              }
            });
          });
          ''');
      } else if (isOneToManyField(field)) {
        // var displayField = getDisplayField(annotation.OneToMany, field);
        var type = getGenericTypes(field.type).first.name;
        setEntityCode.writeln('''_$entityInstance.${field.name} = 
        _$entityInstance.${field.name} ?? List<${type}Entity>();''');
        // setEntityCode.writeln('''list${field.name} = RetryStream(() =>
        //   ${field.type.name}Repository().list()
        //   ).doOnData((${field.name}List) {
        //     ${field.name}List.forEach((${field.name}) {
        //       if (_$entityInstance.${field.name}.$displayField == ${field.name}.$displayField) {
        //           _$entityInstance.${field.name} = ${field.name};
        //       }
        //     });
        //   });
        //   ''');
      }
    });
    declareMethod(entityInstance,
        type: MethodType.setter,
        requiredParameters: [Parameter((b) => b..name = entityInstance)],
        body: Code(setEntityCode.toString()));

    // var entityCode = StringBuffer();
    // // elementAsClass.fields.forEach((field) {
    // //   entityCode.statements
    // //       .add(Code('set${field.name}(${entityInstance}.${field.name});'));
    // // });
    // if (entityCode.isNotEmpty) {
    //   // entityCode.statements.insert(
    //   //     0,
    //   //     Code(
    //   //         'this.$entityInstance.documentId = $entityInstance.documentId;'));
    //   elementAsClass.fields.forEach((field) {
    //     // entityCode.statements.add(Code('_'));
    //   });
    // }
    // declareMethod('set${entityClass}',
    //     requiredParameters: [
    //       Parameter((b) => b
    //         ..name = entityInstance
    //         ..type = refer('${element.name}${manyToManyPosFix}Entity',
    //             '${element.name.toLowerCase()}.entity.dart'))
    //     ],
    //     body: Code('this.$entityInstance = $entityInstance;'));
  }

  void _methodInserOrUpdate() {
    declareMethod('insertOrUpdate',
        returns: refer('Future<dynamic>'), body: Code('''
            if (_$entityInstance.documentId?.isEmpty ?? true) {
            return _repository.add(_$entityInstance);
            } else {
            return _repository.update(_$entityInstance);
            }
            '''));
  }

  void _methodDelete() {
    declareMethod('delete',
        returns: refer('Future<void>'),
        lambda: true,
        body: Code('_repository.delete(_$entityInstance)'));
  }

  void _methodListManyToOne() {
    elementAsClass.fields.forEach((field) {
      if (isManyToOneField(field)) {
        addImportPackage(
            '../${field.type.name.toLowerCase()}/${field.type.name.toLowerCase()}.repository.dart');
        addImportPackage(
            '../${field.type.name.toLowerCase()}/${field.type.name.toLowerCase()}.entity.dart');

        // declareMethod('list${field.type.name}',
        //     returns: refer('Stream<List<${field.type.name}Entity>>'),
        //     lambda: true,
        //     body: Code('${field.type.name}Repository().list()'));
      }
    });
  }

  void _methodHasOneToMany() {
    elementAsClass.fields.forEach((field) {
      if (isOneToManyField(field)) {
        var displayField = getDisplayField(annotation.OneToMany, field);
        var type = getGenericTypes(field.type).first.name;
        declareMethod('has${field.name}',
            returns: refer('bool'),
            requiredParameters: [
              Parameter((b) => b..name = field.name
                  ..type = refer('${type}Entity')
                  )
            ],
            body: Code('''return _$entityInstance.${field.name}
                  .where((${field.name}Where) =>
                  ${field.name}.$displayField == ${field.name}Where.$displayField).length > 0;
                '''));
      }
    });
  }

  void _methodListOneToMany() {
    // elementAsClass.fields.forEach((field) {
    //   if (isOneToManyField(field)) {
    //     addImportPackage(
    //         '../${getGenericTypes(field.type).first.name.toLowerCase()}'
    //         '/${getGenericTypes(field.type).first.name.toLowerCase()}.repository.dart');
    //     addImportPackage(
    //         '../${getGenericTypes(field.type).first.name.toLowerCase()}'
    //         '/${getGenericTypes(field.type).first.name.toLowerCase()}.entity.dart');
    //     declareMethod('list${getGenericTypes(field.type).first}',
    //         returns: refer(
    //             'Stream<List<${getGenericTypes(field.type).first}Entity>>'),
    //         lambda: true,
    //         body: Code(
    //             '${getGenericTypes(field.type).first}Repository().list()'));
    //   }
    // });
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
            body: Code('''
                if (${field.name}Entity.$displayField == 
                $entityInstance.${field.name}?.$displayField) {
                set${field.name}(${field.name}Entity);
                }
                '''));
      }
    });
  }

  void _methodDispose() {
    var disposeCode = StringBuffer();
    // elementAsClass.fields.forEach((field) {
    //   disposeCode.statements.add(Code('_${field.name}Controller.close();'));
    // });
    if (disposeCode.isNotEmpty) {
      disposeCode.writeln('super.dispose();');
      declareMethod('dispose', body: Code(disposeCode.toString()));
    }
  }

  void _methodAddOneToMany() {
    elementAsClass.fields.forEach((field) {
      if (isOneToManyField(field)) {
        var type = getGenericTypes(field.type).first.element.name;
        declareMethod('add${field.name}',
            requiredParameters: [
              Parameter((b) => b
                ..name = '${field.name}Entity'
                ..type = refer('${type}Entity'))
            ],
            body: Code('''if (!has${field.name}(${field.name}Entity))
                $entityInstance.${field.name}.add(${field.name}Entity);
                '''));
      }
    });
  }

  _methodRemoveOneToMany(){
    elementAsClass.fields.forEach((field) {
      if (isOneToManyField(field)) {
        var displayField = getDisplayField(annotation.OneToMany, field);
        var type = getGenericTypes(field.type).first.name;
        declareMethod('remove${field.name}',
            requiredParameters: [
              Parameter((b) => b..name = field.name
                  // ..type = refer(type)
                  )
            ],
            body: Code('''_$entityInstance.${field.name}
                  .removeWhere((${field.name}Where) =>
                  ${field.name}.$displayField == ${field.name}Where.$displayField);
                '''));
      }
    });
  }

  void _methodAddManyToMany() {
    elementAsClass.fields
        .where((field) => isManyToManyField(field))
        .forEach((field) {
      var type = getGenericTypes(field.type).first.element.name;
      declareMethod('add${field.name}ManyToMany',
          requiredParameters: [
            Parameter((b) => b
              ..name = '${field.name.toLowerCase()}ManyToMany'
              ..type = refer(type))
          ],
          body: Code('''if ($entityInstance.${field.name} == null)
              $entityInstance.${field.name} = List<$type>();
              $entityInstance.${field.name}.add(${field.name.toLowerCase()}ManyToMany);
              notifyListeners();'''));
    });
  }

  @override
  GenerateClassForAnnotation instance() => BlocGenerator()
    ..manyToMany = true
    ..generateImport = false;

  // _methodDateTimeFormat() {
  //   var blockBuilder = BlockBuilder()
  //     ..statements.addAll([
  //       Code('var dateFormat;'),
  //       Code('if (context == null) {'),
  //       Code('dateFormat = DateFormat.yMMMMd();'),
  //       Code('}'),
  //       Code('else {'),
  //       Code(
  //           'dateFormat = DateFormat.yMMMMd(Localizations.localeOf(context).languageCode);'),
  //       Code('}'),
  //       Code('return dateFormat.add_Hm().format(dateTime);')
  //     ]);

  //   declareMethod('dateTimeFormat',
  //       returns: refer('String'),
  //       requiredParameters: [
  //         Parameter((b) => b
  //           ..name = 'dateTime'
  //           ..type = refer('DateTime'))
  //       ],
  //       body: blockBuilder.build());
  //   if (generateImport) addImportPackage('package:intl/intl.dart');
  // }
}
