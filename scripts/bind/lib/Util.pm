package Util;

use strict;
use warnings;

use Class;

our @EXPORT = qw(
	&fatal
	
	&getUniqueID
	
	&makeNamespaceSymbol

	&assignValues
	
	&getWrittenFileCount
	&getSkippedFileCount

	&writeToFile
	
	&findItemByName
	&listPush
	&getBaseName
	&valueYesNo
	&getAttribute

	&getBaseFileName
	&defineMetaClass

	&fixupClassList
	&dumpClass

	&writeParamList

	&itemIsPublic
	&itemIsProtected
	&itemIsPrivate
);

my $currentUniqueID = 0;

my $writtenFileCount = 0;
my $skippedFileCount = 0;

sub getWrittenFileCount { return $writtenFileCount; }
sub getSkippedFileCount { return $skippedFileCount; }

sub fatal
{
	my @msg = @_;

	print @msg;
	die "\n";
}

sub getUniqueID
{
	++$currentUniqueID;
	return $currentUniqueID;
}

sub makeNamespaceSymbol
{
	my ($config) = @_;
	
	return '_mEta_nS_' . $config->{id};
}

sub assignValues
{
	my ($object, $values) = @_;

	foreach(keys %{$values}) {
		$object->{$_} = $values->{$_};
	}
}

sub writeToFile
{
	my ($fileName, $content) = @_;

	if(open FH, '<' . $fileName) {
		my @lines = <FH>;

		close FH;

		my $oldText = join('', @lines);

		if($content eq $oldText) {
			++$skippedFileCount;

#			print "Same file $fileName ... skipped. \n";

			return;
		}

	}

	++$writtenFileCount;

	print "Write to file $fileName. \n";
	open FH, '>' . $fileName or fatal("Can't write to file $fileName. \n");
	print FH $content;
	close FH;
}

sub findItemByName
{
	my ($itemList, $name) = @_;

	foreach(@{$itemList}) {
		my $base = $_;
		if(defined($base->getName) and ($base->getName eq $name)) {
			return $base;
		}
	}

	return undef;
}

sub listPush
{
	my ($list, $item) = @_;

	push @{$list}, $item;
}

sub getBaseName
{
	my ($name) = @_;

	$name =~ s/^.*\b(\w+)$/$1/;

	return $name;
}

sub valueYesNo
{
	my ($s) = @_;

	return lc($s) eq 'no' ? 0 : 1;
}

sub getNode
{
	my ($xmlNode, $nodeName) = @_;
	
	return undef unless defined $xmlNode;
	my $nodeList = $xmlNode->getElementsByTagName($nodeName, 0);
	return $nodeList->[0];
}

sub getAttribute
{
	my ($xmlNode, $attrName) = @_;

	return undef unless defined $xmlNode;
	my $attrNode = $xmlNode->getAttributes()->getNamedItem($attrName);
	return defined $attrNode ? $attrNode->getValue() : undef;
}

sub getNodeText
{
	my ($xmlNode, $attrName) = @_;
	
	return undef unless defined $xmlNode;

	my $result = '';

	foreach($xmlNode->getChildNodes()) {
		my $node = $_;

		if($node->getNodeName() eq '#text') {
			$result .= $node->getData();
		}
		else {
			$result .= getNodeText($node);
		}
	}

	return $result;
}

sub getBaseFileName
{
	my ($fn) = @_;
	
	$fn =~ s/\.[^.]+$//;
	
	return $fn;
}

sub defineMetaClass
{
	my ($config, $codeWriter, $class, $varName, $action, $rules, $code) = @_;
	
	my $namespace = Util::makeNamespaceSymbol($config);
	
	if($config->{hardcodeNamespace}) {
		if($class->isGlobal()) {
			if(defined $config->{namespace}) {
				$codeWriter->out('GDefineMetaClass<void> ' . $varName . ' = GDefineMetaClass<void>::' . $action . '(' . $namespace . ");\n");
			}
			else {
				$codeWriter->out("GDefineMetaGlobal " . $varName . ";\n");
			}
			
			$codeWriter->out($code . "\n");
		}
		else {
			my $typeName = "GDefineMetaClass<" . $class->getName;
			foreach(@{$class->{baseNameList}}) {
				my @names = split('~', $_);
				if($names[1] eq 'public') {
					$typeName .= ", " . $names[0];
				}
			}
			$typeName .= ">";
			my $policy = '';
			if(defined($rules) and $#{@{$rules}} >= 0) {
				$policy = '::Policy<MakePolicy<' . join(', ', @{$rules}) . '> >';
			}
			if(defined $config->{namespace}) {
				$codeWriter->out('GDefineMetaClass<void> _ns = GDefineMetaClass<void>::' . $action . '(' . $namespace . ");\n");
				$codeWriter->out($typeName .  " " . $varName . " = " . $typeName . $policy . "::declare(\"" . Util::getBaseName($class->getName) . "\");\n");
				$codeWriter->out("_ns._class(" . $varName . ");\n");
			}
			else {
				$codeWriter->out($typeName .  " " . $varName . " = " . $typeName . $policy . "::" . $action . "(\"" . Util::getBaseName($class->getName) . "\");\n");
			}
			
			$codeWriter->out($code . "\n");
		}

		return;
	}
	
	if($class->isGlobal()) {
		$codeWriter->out("if(" . $namespace . ") {\n");
		$codeWriter->incIndent();
		$codeWriter->out('GDefineMetaClass<void> ' . $varName . ' = GDefineMetaClass<void>::' . $action . '(' . $namespace . ");\n");
		$codeWriter->out($code . "\n");
		$codeWriter->decIndent();
		$codeWriter->out("}\n");
		
		$codeWriter->out("else {\n");
		$codeWriter->incIndent();
		$codeWriter->out("GDefineMetaGlobal " . $varName . ";\n");
		$codeWriter->out($code . "\n");
		$codeWriter->decIndent();
		$codeWriter->out("}\n");
	}
	else {
		my $typeName = "GDefineMetaClass<" . $class->getName;
		foreach(@{$class->{baseNameList}}) {
			my @names = split('~', $_);
			if($names[1] eq 'public') {
				$typeName .= ", " . $names[0];
			}
		}
		$typeName .= ">";
		my $policy = '';
		if(defined($rules) and $#{@{$rules}} >= 0) {
			$policy = '::Policy<MakePolicy<' . join(', ', @{$rules}) . '> >';
		}
		$codeWriter->out("if(" . $namespace . ") {\n");
		$codeWriter->incIndent();
		$codeWriter->out('GDefineMetaClass<void> _ns = GDefineMetaClass<void>::' . $action . '(' . $namespace . ");\n");
		$codeWriter->out($typeName .  " " . $varName . " = " . $typeName . $policy . "::declare(\"" . Util::getBaseName($class->getName) . "\");\n");
		$codeWriter->out("_ns._class(" . $varName . ");\n");
		$codeWriter->out($code . "\n");
		$codeWriter->decIndent();
		$codeWriter->out("}\n");

		$codeWriter->out("else {\n");
		$codeWriter->incIndent();
		$codeWriter->out($typeName .  " " . $varName . " = " . $typeName . $policy . "::" . $action . "(\"" . Util::getBaseName($class->getName) . "\");\n");
		$codeWriter->out($code . "\n");
		$codeWriter->decIndent();
		$codeWriter->out("}\n");
	}
}

sub itemIsPublic
{
	my ($item) = @_;

	return $item->getVisibility eq 'public';
}

sub itemIsProtected
{
	my ($item) = @_;

	return $item->getVisibility eq 'protected';
}

sub itemIsPrivate
{
	my ($item) = @_;

	return $item->getVisibility eq 'private';
}

sub fixupClassList
{
	my ($classList) = @_;

	$classList = &doFixupGlobals($classList);
	$classList = &doFixupBases($classList);
	$classList = &doFixupInners($classList);

	return $classList;
}

sub doFixupGlobals
{
	my ($classList) = @_;

	my %fileMap = ();
	my $finished = 0;
	while(not $finished) {
		$finished = 1;

		for(my $i = 0; $i <= $#{@{$classList}}; ++$i) {
			my $c = $classList->[$i];
			next unless($c->isGlobal());

			&doFixupGlobalItems(\%fileMap, $c->{fieldList});
			&doFixupGlobalItems(\%fileMap, $c->{methodList});
			&doFixupGlobalItems(\%fileMap, $c->{operatorList});
			&doFixupGlobalItems(\%fileMap, $c->{enumList});
			&doFixupGlobalItems(\%fileMap, $c->{defineList});

			splice(@{$classList}, $i, 1);
			$finished = 0;
			last;
		}
	}

	foreach(values(%fileMap)) {
		unshift @{$classList}, $_;
	}

	return $classList;
}

sub doFixupGlobalItems
{
	my ($fileMap, $itemList) = @_;

	foreach(@{$itemList}) {
		my $item = $_;
		my $location = $item->getLocation;
		if(not defined $fileMap->{$location}) {
			$fileMap->{$location} = new Class;
			$fileMap->{$location}->setLocation($location);
		}
		&listPush($item->getList($fileMap->{$location}), $item);
	}
}

sub doFixupBases
{
	my ($classList) = @_;

	foreach(@{$classList}) {
		my $target = $_;
		$target->{baseList} = [];

		foreach(@{$target->{baseNameList}}) {
			my @names = split('~', $_);
			my $baseClass = &findItemByName($classList, $names[0]);
			if(defined $baseClass) {
				push @{$target->{baseList}}, $baseClass;
			}
		}
	}

	return $classList;
}

sub doFixupInners
{
	my ($classList) = @_;

	foreach(@{$classList}) {
		my $target = $_;
		$target->{classList} = [];

		foreach(@{$target->{classNameList}}) {
			my @names = split('~', $_);
			my $innerClass = &findItemByName($classList, $names[0]);
			if(defined $innerClass) {
				$innerClass->{inner} = 1;
				push @{$target->{classList}}, $innerClass;
				$innerClass->setVisibility($names[1]);
			}
		}
	}
	
	for(my $i = $#{@{$classList}}; $i >= 0; --$i) {
		my $c = $classList->[$i];
		if($c->{inner}) {
			splice(@{$classList}, $i, 1);
		}
	}

	return $classList;
}

sub mergeClasses
{
	my ($a, $b) = @_;

	$a->{baseList} = &mergeArrays($a->{baseList}, $b->{baseList});
	$a->{constructorList} = &mergeArrays($a->{constructorList}, $b->{constructorList});
	$a->{fieldList} = &mergeArrays($a->{fieldList}, $b->{fieldList});
	$a->{methodList} = &mergeArrays($a->{methodList}, $b->{methodList});
	$a->{enumList} = &mergeArrays($a->{enumList}, $b->{enumList});
	$a->{operatorList} = &mergeArrays($a->{operatorList}, $b->{operatorList});
	$a->{classList} = &mergeArrays($a->{classList}, $b->{classList});

	return $a;
}

sub mergeArrays
{
	my ($a, $b) = @_;

	foreach(@{$b}) {
		push @{$a}, $_;
	}

	return $a;
}

sub writeParamList
{
	my ($writer, $paramList, $withName) = @_;
	my $comma = 0;
	foreach(@{$paramList}) {
		my $p = $_;
		$writer->out(', ') if($comma);
		&writeParam($writer, $p, $withName);
		$comma = 1;
	}
}

sub writeParam
{
	my ($writer, $param, $withName) = @_;
	
	$writer->out($param->{type} . ($withName ? ' ' . $param->getName : ''));
}


1;