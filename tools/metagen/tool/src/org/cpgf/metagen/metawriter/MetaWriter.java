package org.cpgf.metagen.metawriter;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;

import org.cpgf.metagen.Config;
import org.cpgf.metagen.Util;
import org.cpgf.metagen.codewriter.CppWriter;
import org.cpgf.metagen.doxyxmlparser.FileInfo;
import org.cpgf.metagen.doxyxmlparser.FileMap;
import org.cpgf.metagen.metadata.CppClass;
import org.cpgf.metagen.metadata.MetaInfo;


public class MetaWriter {
	private List<MetaFileWriter> fileWriterList;
	private MetaInfo metaInfo;
	private List<CppClass> classList;
	private Config config;
	private FileMap fileMap;

	public MetaWriter(Config config, MetaInfo metaInfo, FileMap fileMap) {
		this.metaInfo = metaInfo;
		this.classList = this.metaInfo.getClassList();
		this.fileMap = fileMap;
		this.config = config;

		this.fileWriterList = new ArrayList<MetaFileWriter>();
	}

	public void write() throws Exception
	{
		List<String> createFunctionNames = new ArrayList<String>();

		Util.trace("Building file information.");

		this.buildFileWriterList();

		Util.trace("Writing files.");

		for(MetaFileWriter fileWriter : this.fileWriterList) {
			fileWriter.writeHeader();
			fileWriter.writeSource(createFunctionNames);
		}

		this.createMainHeader(createFunctionNames);
		this.createMainSource(createFunctionNames);
	}

	private String getMainFileName() {
		return this.config.mainSourceFile;
	}

	private String getMainFunctionName() {
		return this.config.metaClassMainRegisterPrefix + this.config.projectID;
	}

	private void createMainHeader(List<String> createFunctionNames) throws Exception {
		if(! this.config.autoRegisterToGlobal) {
			return;
		}
		
		String outFileName = Util.concatFileName(this.config.headerOutput, this.getMainFileName()) + ".h";
		CppWriter codeWriter = new CppWriter();

		WriterUtil.writeCommentForAutoGeneration(codeWriter);	

		codeWriter.beginIncludeGuard(Util.normalizeSymbol(this.getMainFileName()) + "_H");

		codeWriter.include("cpgf/gmetadefine.h");

		codeWriter.writeLine("");
		codeWriter.writeLine("");
		
		codeWriter.useNamespace("cpgf");
		codeWriter.writeLine("");

		codeWriter.beginNamespace(this.config.cppNamespace);
		
		List<String> sortedCreateFunctionNames = Util.sortStringList(createFunctionNames);

		for(String funcName : sortedCreateFunctionNames) {
			codeWriter.writeLine("GDefineMetaInfo " + funcName + "();");
		}
		
		codeWriter.writeLine("");
		codeWriter.writeLine("");

		codeWriter.writeLine("template <typename Meta>");
		codeWriter.writeLine("void " + this.getMainFunctionName() + "(Meta _d)");

		codeWriter.beginBlock();

		for(String funcName : sortedCreateFunctionNames) {
			codeWriter.writeLine("_d._class(" + funcName + "());");
		}

		codeWriter.endBlock();
		
		codeWriter.writeLine("");
		
		codeWriter.endNamespace(this.config.cppNamespace);

		codeWriter.endIncludeGuard();	

		Util.writeTextToFile(outFileName, codeWriter.getText());
	}

	private void createMainSource(List<String> createFunctionNames) throws Exception {
		if(! this.config.autoRegisterToGlobal) {
			return;
		}
		
		String outFileName = Util.concatFileName(this.config.sourceOutput, this.getMainFileName()) + ".cpp";
		CppWriter codeWriter = new CppWriter();

		WriterUtil.writeCommentForAutoGeneration(codeWriter);	

		codeWriter.include(this.config.metaHeaderPath + this.getMainFileName() + ".h");
		codeWriter.include("cpgf/gmetadefine.h");
		codeWriter.include("cpgf/goutmain.h");

		codeWriter.writeLine("");
		codeWriter.writeLine("");
		
		codeWriter.useNamespace("cpgf");
		codeWriter.writeLine("");

		codeWriter.beginNamespace(this.config.cppNamespace);
		
		codeWriter.beginNamespace("");

		codeWriter.writeLine("G_AUTO_RUN_BEFORE_MAIN()");

		codeWriter.beginBlock();

		CppClass global = new CppClass(null);
		WriterUtil.defineMetaClass(this.config, codeWriter, global, "_d", "define");

		codeWriter.writeLine(this.getMainFunctionName() + "(_d);");

		codeWriter.endBlock();
		codeWriter.writeLine("");

		codeWriter.endNamespace("");
		
		codeWriter.endNamespace(this.config.cppNamespace);

		Util.writeTextToFile(outFileName, codeWriter.getText());
	}

	private void buildFileWriterList()
	{
		HashMap<String, MetaFileWriter> locationFileWriterMap = new HashMap<String, MetaFileWriter>();

		for(CppClass item : this.classList) {
			String location = item.getLocation();
			String key = location.toLowerCase();

			FileInfo fileInfo = this.fileMap.getFileMap().get(location);
			if(fileInfo == null) {
				continue;
			}
			
			if(! locationFileWriterMap.containsKey(key)) {
				MetaFileWriter fileWriter = new MetaFileWriter(
					this.config,
					this.metaInfo,
					location,
					fileInfo
				);
				locationFileWriterMap.put(key, fileWriter);
				this.fileWriterList.add(fileWriter);
			}
			locationFileWriterMap.get(key).addClass(item);
		}
	}


}