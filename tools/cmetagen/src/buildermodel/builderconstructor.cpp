#include "builderconstructor.h"
#include "builderfilewriter.h"
#include "codewriter/cppwriter.h"
#include "model/cppconstructor.h"

#include "Poco/Format.h"


BuilderConstructor::BuilderConstructor(const CppItem * cppItem)
	: super(cppItem)
{
	this->checkBuilderItemCategory(icConstructor);
}

BuilderConstructor::~BuilderConstructor()
{
}

const CppConstructor * BuilderConstructor::getCppConstructor() const
{
	return static_cast<const CppConstructor *>(this->getCppItem());
}

void BuilderConstructor::doWriteMetaData(BuilderFileWriter * writer)
{
	const CppConstructor * cppConstructor = this->getCppConstructor();
	CodeBlock * codeBlock = writer->getReflectionCodeBlock(cppConstructor);

	std::string s = Poco::format("%s<void * (%s)>());",
		writer->getReflectionAction("_constructor"),
		cppConstructor->getTextOfParamList(itoWithType)
	);

	codeBlock->addLine(s);
}
