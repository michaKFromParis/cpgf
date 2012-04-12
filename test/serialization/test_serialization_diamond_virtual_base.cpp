#include "testserializationcommon.h"
#include "cpgf/gmetadefine.h"

#include <sstream>

#include <iostream>

using namespace std;
using namespace cpgf;


namespace {

int readCount = 0;
int writeCount = 0;

class A
{
public:
	A() : a(0) {}
	virtual ~A() {}

	int getA() const {
		++readCount;
		return a;
	}
	
	void setA(int a) {
		++writeCount;
		this->a = a;
	}

	int a;
};

class B : virtual public A
{
public:
	B() : b(0) {}

	int b;
};

class C : virtual public A
{
public:
	C() : c(0) {}

	int c;
};

class D : public B, public C
{
public:
	D() : d(0) {}

	bool operator == (const D & other) const {
		return
			this->a == other.a
			&& this->b == other.b
			&& this->c == other.c
			&& this->d == other.d
		;
	}
	
	bool operator != (const D & other) const {
		return
			this->a != other.a
			&& this->b != other.b
			&& this->c != other.c
			&& this->d != other.d
		;
	}
	
	int d;
};



template <typename Define>
void register_TestSerializeClass(Define define)
{
	GDefineMetaClass<A> classDefineA = GDefineMetaClass<A>::declare("TestSerializeClassA");
	
	classDefineA
		._property("a", &A::getA, &A::setA)
	;

	define._class(classDefineA);
	
	GDefineMetaClass<B, A> classDefineB = GDefineMetaClass<B, A>::declare("TestSerializeClassB");
	
	classDefineB
		FIELD(B, b)
	;

	define._class(classDefineB);

	GDefineMetaClass<C, A> classDefineC = GDefineMetaClass<C, A>::declare("TestSerializeClassC");
	
	classDefineC
		FIELD(C, c)
	;

	define._class(classDefineC);
	
	GDefineMetaClass<D, B, C> classDefineD = GDefineMetaClass<D, B, C>::declare("TestSerializeClassD");
	
	classDefineD
		FIELD(D, d)
	;

	define._class(classDefineD);

}

template <typename READER, typename AR>
void doTestDiamondVirtualBase(IMetaWriter * writer, const READER & reader, const AR & ar)
{
	const char * const serializeObjectName = "diamondVirtualBase";
	
	GDefineMetaNamespace define = GDefineMetaNamespace::declare("global");
	register_TestSerializeClass(define);

	GMetaModule module;
	GScopedInterface<IMetaModule> moduleInterface(createMetaModule(&module, define.getMetaClass()));
	GScopedInterface<IMetaService> service(createMetaService(moduleInterface.get()));

	readCount = 0;
	writeCount = 0;

	GScopedInterface<IMetaArchiveWriter> archiveWriter(createMetaArchiveWriter(service.get(), writer));

	GScopedInterface<IMetaClass> metaClass(service->findClassByName("TestSerializeClassD"));

	D instance;
	instance.a = 0x1a;
	instance.b = 0x2b;
	instance.c = 0x3c;
	instance.d = 0x4d;

	serializeWriteObjectValue(archiveWriter.get(), serializeObjectName, &instance, metaClass.get());

	ar.rewind();
	
	GScopedInterface<IMetaArchiveReader> archiveReader(createMetaArchiveReader(service.get(), reader.get(service.get())));
	
	D readInstance;
	
	GCHECK(instance != readInstance);

	serializeReadObject(archiveReader.get(), serializeObjectName, &readInstance, metaClass.get());

	GEQUAL(instance, readInstance);

	GEQUAL(1, readCount);
	GEQUAL(1, writeCount);
}

GTEST(testDiamondVirtualBase_TextStream)
{
	stringstream stream;

	GScopedInterface<IMetaWriter> writer(createTextStreamMetaWriter(stream));
	
	doTestDiamondVirtualBase(writer.get(), MetaReaderGetter(stream), TestArchiveStream<stringstream>(stream));
	
//	cout << stream.str().c_str() << endl;
}


GTEST(testDiamondVirtualBase_Xml)
{
	GMetaXmlArchive outputArchive;

	GScopedInterface<IMetaWriter> writer(createXmlMetaWriter(outputArchive));
	
	doTestDiamondVirtualBase(writer.get(), MetaReaderGetterXml(outputArchive), TestArchiveStreamNone());
	
//	outputArchive.saveToStream(cout);
}


GTEST(testDiamondVirtualBase_Json)
{
	GMetaJsonArchive outputArchive;

	GScopedInterface<IMetaWriter> writer(createJsonMetaWriter(outputArchive));
	
	doTestDiamondVirtualBase(writer.get(), MetaReaderGetterJson(outputArchive), TestArchiveStreamNone());
	
//	outputArchive.saveToStream(cout);
}


} // unnamed namespace
