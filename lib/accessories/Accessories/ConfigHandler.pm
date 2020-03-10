#!/usr/bin/perl

package ConfigHandler;

use strict;
use warnings;

use YAML::XS qw(LoadFile);
use JSON;

$| = 1;

sub new {
	my $class = shift;
	my $self = { module => "confighandler"};
	bless $self, $class;
	my $sub = (caller(0))[3];

	return $self;
}

sub readYaml {
	my ($self, $options) = @_; #required: yamlFile
	my $sub = (caller(0))[3];
	
	my $yamlObject;
	eval {
		my @required;
		push @required, "yamlFile" if (!defined($options->{yamlFile}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		$yamlObject = LoadFile($options->{yamlFile}) or die "Can not load $options->{yamlFile}";
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return $yamlObject;
	}
}

sub readJson {
	my ($self, $options) = @_; #required: jsonFile
	my $sub = (caller(0))[3];
	
	my $jsonObject;
	eval {
		my @required;
		push @required, "jsonFile" if (!defined($options->{jsonFile}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		open my $jsonFile, "<:encoding(UTF-8)", $options->{jsonFile}
		or die "Can not open $options->{jsonFile}\n";
		local $/ = undef;
		$jsonObject = <$jsonFile>;
		close $jsonFile;
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return decode_json($jsonObject);
	}
}

sub readIniAppConfig {
	my ($self, $options) = @_; #required: iniFile, commentSymbol
	my $sub = (caller(0))[3];
	
	my @iniObject;
	eval {
		my @required;
		push @required, "iniFile" if (!defined($options->{iniFile}));
		push @required, "commentSymbol" if (!defined($options->{commentSymbol}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		open(my $iniFile, "<", "$options->{iniFile}")
		or die "Can not open $options->{iniFile}";
		my $section;
		my $comment;
		while (my $line = <$iniFile>) {		
			next if ($line =~ /^\s*$/); # empty lines
			
			if ($line =~ /^\s*$options->{commentSymbol}/) {  # comments
				chomp $line;
				$line =~ s/^\s+//;
				$line = reverse($line);
				chop($line);
				$line = reverse($line);
				$line =~ s/^\s+//;
				if (defined($comment)) {
					$comment = $comment." $options->{commentSymbol} ".$line;
				} else {
					$comment = $line;
				}
				next;       
			}

			if ($line =~ /^\[(.*)\]\s*$/) {  # section
				$section = $1;
				my $sectionHash;
				$sectionHash->{Section} = $section;
				if (defined($comment)) {
					$sectionHash->{Description} = $comment;
					undef $comment;
				} else {
					$sectionHash->{Description} = "";
				}
				push @iniObject, $sectionHash;
				next;
			}

			if ($line =~ /^([^=]+?)\s*=\s*(.*?)\s*$/) { # parameter
				my ($field, $value) = ($1, $2);
				if (not defined $section) {
					warn "Line outside of section $line\n";
					next;
				}
				my $parameterHash;
				$parameterHash->{Parameter} = $field;
				$parameterHash->{Value} = $value;
				if (defined($comment)) {
					$parameterHash->{Description} = $comment;
					undef $comment;
				} else {
					$parameterHash->{Description} = "";
				}
				push @{$iniObject[@iniObject - 1]->{Parameters}}, $parameterHash;
			}
		}
		close $iniFile;
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return \@iniObject;
	}
}


sub writeSystemDescriptionToYaml { 
	my ($self, $options) = @_; #required: systemName, yamlFile
	my $sub = (caller(0))[3];
	
	eval {
		die "systemName required" if (!defined($options->{systemName}));
		die "yamlFile required" if (!defined($options->{yamlFile}));
		$options->{yamlFile} =~ tr#\\#/#;
		
		open(my $yamlFile, ">>", "$options->{yamlFile}")
		or die "Can not open $options->{yamlFile}";
		
		my $t = "    ";
		
		foreach my $component (@{$self->{systemDescriptions}->{$options->{systemName}}}) {
		
			print $yamlFile "-"."\n";
			print $yamlFile  "$t"."name: "."\"".$component->{name}."\""."\n";
			print $yamlFile  "$t"."ip: "."\"".$component->{ip}."\""."\n";
			print $yamlFile  "$t"."port: "."\"".$component->{port}."\""."\n";
			print $yamlFile  "$t"."ctermPort: "."\"".$component->{ctermPort}."\""."\n";
			print $yamlFile  "$t"."binApp: "."\"".$component->{binApp}."\""."\n";
			print $yamlFile  "$t"."binPath: "."\"".$component->{binPath}."\""."\n";
			print $yamlFile  "$t"."binElements: "."\n";
			foreach my $binElement (@ {$component->{binElements}}) {
				print $yamlFile "$t$t- "."\""."$binElement"."\""."\n";
			}
			print $yamlFile  "$t"."statePath: "."\"".$component->{statePath}."\""."\n";
			print $yamlFile  "$t"."counters: "."\n";
			foreach my $counterHash (@ {$component->{counters}}) {
				print $yamlFile "$t$t-"."\n";
				print $yamlFile  "$t$t$t"."counter: "."\"".$counterHash->{counter}."\""."\n";
				print $yamlFile "$t$t$t"."path: "."\"".$counterHash->{path}."\""."\n";
				print $yamlFile "$t$t$t"."type: "."\"".$counterHash->{type}."\""."\n";
			}
			print $yamlFile  "$t"."alarms: "."\n";
			foreach my $alarmHash (@ {$component->{alarms}}) {
				print $yamlFile "$t$t-"."\n";
				print $yamlFile  "$t$t$t"."alarm: "."\"".$alarmHash->{alarm}."\""."\n";
				print $yamlFile "$t$t$t"."rule: "."\"".$alarmHash->{rule}."\""."\n";
				print $yamlFile "$t$t$t"."priority: "."\"".$alarmHash->{priority}."\""."\n";
			}
			print $yamlFile  "$t"."config: "."\n";
			foreach my $sectionHash (@ {$component->{config}}) {
				print $yamlFile "$t$t-"."\n";
				print $yamlFile  "$t$t$t"."Section: "."\"".$sectionHash->{Section}."\""."\n";
				print $yamlFile "$t$t$t"."Description: "."\"".$sectionHash->{Description}."\""."\n";
				print $yamlFile "$t$t$t"."Parameters:"."\n";
				foreach my $parameterHash (@{$sectionHash->{Parameters}}) {
					print $yamlFile "$t$t$t$t"."-"."\n";
					print $yamlFile "$t$t$t$t$t"."Parameter: "."\"".$parameterHash->{Parameter}."\""."\n";
					print $yamlFile "$t$t$t$t$t"."Description: "."\"".$parameterHash->{Description}."\""."\n";
					print $yamlFile "$t$t$t$t$t"."Value: "."\"".$parameterHash->{Value}."\""."\n";
				}
			}
		
		}

		close $yamlFile;
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}

sub writeAppConfigToIni {
	my ($self, $options) = @_; #required: componentName, iniFile, commentSymbol
	my $sub = (caller(0))[3];
	
	eval {
		die "componentName required" if (!defined($options->{componentName}));
		$options->{componentName} =~ tr#\\#/#;
		die "$options->{componentName} required" if (!defined($self->{componentConfigs}->{$options->{componentName}}));
		die "iniFile required" if (!defined($options->{iniFile}));
		$options->{iniFile} =~ tr#\\#/#;
		die "commentSymbol required" if (!defined($options->{commentSymbol}));
		
		die "$options->{iniFile} already exists" if (-e $options->{iniFile});	
		open(my $iniFile, ">", "$options->{iniFile}")
		or die "Can not open $options->{iniFile}";

		foreach my $sectionHash (@ {$self->{componentConfigs}->{$options->{componentName}}}) {
			if ($sectionHash->{Description} ne "") {
				$sectionHash->{Description} =~ s/ $options->{commentSymbol} /\n$options->{commentSymbol} /g;
				print $iniFile "\n"."$options->{commentSymbol} ".$sectionHash->{Description}."\n";
			} else {
				print $iniFile "\n";
			}
			print $iniFile "[".$sectionHash->{Section}."]"."\n";
			foreach my $parameterHash (@{$sectionHash->{Parameters}}) {
				if ($parameterHash->{Description} ne "") {
					$parameterHash->{Description} =~ s/ $options->{commentSymbol} /\n$options->{commentSymbol} /g;
					print $iniFile "$options->{commentSymbol} ".$parameterHash->{Description}."\n";
				}
				if ($parameterHash->{Value} ne "") {
					print $iniFile $parameterHash->{Parameter}."=".$parameterHash->{Value}."\n";
				} else {
					print $iniFile $parameterHash->{Parameter}."="."\n";
				}
			}
		}
		close $iniFile;
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}

sub writeAppConfigToYaml {
	my ($self, $options) = @_; #required: componentName, yamlFile
	my $sub = (caller(0))[3];
	
	eval {
		die "componentName required" if (!defined($options->{componentName}));
		$options->{componentName} =~ tr#\\#/#;
		die "$options->{componentName} required" if (!defined($self->{componentConfigs}->{$options->{componentName}}));
		die "yamlFile required" if (!defined($options->{yamlFile}));
		$options->{yamlFile} =~ tr#\\#/#;
		
		die "$options->{yamlFile} already exists" if (-e $options->{yamlFile});
		open(my $yamlFile, ">", "$options->{yamlFile}")
		or die "Can not open $options->{yamlFile}";

		foreach my $sectionHash (@ {$self->{componentConfigs}->{$options->{componentName}}}) {
			print $yamlFile "-"."\n";
			print $yamlFile  "    "."Section: "."\"".$sectionHash->{Section}."\""."\n";
			print $yamlFile "    "."Description: "."\"".$sectionHash->{Description}."\""."\n";
			print $yamlFile "    "."Parameters:"."\n";
			foreach my $parameterHash (@{$sectionHash->{Parameters}}) {
				print $yamlFile "    "."    "."-"."\n";
				print $yamlFile "    "."    "."    "."Parameter: "."\"".$parameterHash->{Parameter}."\""."\n";
				print $yamlFile "    "."    "."    "."Description: "."\"".$parameterHash->{Description}."\""."\n";
				print $yamlFile "    "."    "."    "."Value: "."\"".$parameterHash->{Value}."\""."\n";
			}
		}

		close $yamlFile;	
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}

sub writeAppConfigToJsonSchema {
	my ($self, $options) = @_; #required: appRef, jsonSchemaFile
	my $sub = (caller(0))[3];
	
	eval {
		my @required;
		push @required, "appRef" if (!defined($options->{appRef}));
		push @required, "jsonSchemaFile" if (!defined($options->{jsonSchemaFile}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		my $fsize = -s $options->{jsonSchemaFile};  
		open(my $jsonSchemaFile, "+<", $options->{jsonSchemaFile}) or die "can not open $options->{jsonSchemaFile}"; 
		seek $jsonSchemaFile, $fsize-1, 0; 
		read $jsonSchemaFile, my $char, 1;
		if ($char eq "]") {
			seek $jsonSchemaFile, $fsize-4, 0;
			read $jsonSchemaFile, $char, 1;
			if ($char eq "}") {
				seek $jsonSchemaFile, $fsize-3, 0;
				print $jsonSchemaFile ",";
			
			}
			seek $jsonSchemaFile, $fsize-1, 0;
			print $jsonSchemaFile "\t{\n\t\t\"App\": \"${$options->{appRef}}->{name}\", \"Sections\": [";
			close $jsonSchemaFile;
		
			open(my $jsonSchemaFile, ">>", "$options->{jsonSchemaFile}") or die "can not open $options->{jsonSchemaFile}";

			my $isFirstSection = 1;
			foreach my $sectionHash (@{${$options->{appRef}}->{config}}) {
				if (!$isFirstSection) {
					print $jsonSchemaFile "," 
				} else { $isFirstSection = 0; }
				print $jsonSchemaFile "\n\t\t\t{";
				print $jsonSchemaFile "\n\t\t\t\t\"Section\": \"$sectionHash->{Section}\", ";
				print $jsonSchemaFile "\"Description\": \"$sectionHash->{Description}\"";
				print $jsonSchemaFile ", \"Parameters\": [";
			
				my $isFirstParameter = 1;
				foreach my $parameterHash (@{$sectionHash->{Parameters}}) {
					if (!$isFirstParameter) {
						print $jsonSchemaFile "," 
					} else { $isFirstParameter = 0; }
					print $jsonSchemaFile "\n\t\t\t\t\t{";
					print $jsonSchemaFile "\n\t\t\t\t\t\t\"Parameter\": \"$parameterHash->{Parameter}\", ";
					print $jsonSchemaFile "\"Description\": \"$parameterHash->{Description}\"";
					print $jsonSchemaFile ", \"Value\": \"$parameterHash->{Value}\"";
					print $jsonSchemaFile "\n\t\t\t\t\t}";
				}
				print $jsonSchemaFile "\n\t\t\t\t]\n";
				print $jsonSchemaFile "\n\t\t\t}";
			}

			print $jsonSchemaFile "\n\t\t]\n\t}\n]";
		}
		close $jsonSchemaFile;
	
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}

sub writeAppConfigTemplateToJsonSchema {
	my ($self, $options) = @_; #required: jsonSchemaFile
	my $sub = (caller(0))[3];
	
	eval {
		my @required;
		push @required, "jsonSchemaFile" if (!defined($options->{jsonSchemaFile}));
		my $req = join(", ", @required);
		die "$req required" if (scalar(@required));
		
		die "$options->{jsonSchemaFile} already exists" if (-e $options->{jsonSchemaFile});
		
		open(my $jsonSchemaFile, ">", "$options->{jsonSchemaFile}")
		or die "Can not open $options->{jsonSchemaFile}";
		
my $template = 
'{
	"title": "Apps",
	"type": "array",
	"format": "tabs",
	"uniqueItems": true,
	"items": {
		"type": "object",
		"headerTemplate": "{{self.App}}",
		"properties": {
			"App": {
				"type": "string",
				"propertyOrder": 1
			},
			
			"Sections":{
				"type": "array",
				//"format": "tabs",
				"uniqueItems": true,
				"propertyOrder": 2,
				"items": {
					"type": "object",
					"headerTemplate": "{{self.Section}}",
					"properties": {
						"Section": {
							"type": "string",
							"propertyOrder": 1
						},
						"Description": {
							"type": "string",
							"propertyOrder": 2,
							"options": {
								//"hidden": true
							}
						},
						"Parameters":
						{
							"type": "array",
							"format": "table",
							"uniqueItems": true,
							"propertyOrder": 3,
							"items": {
								"type": "object",
								"properties": {
									"Parameter": {
										"type": "string",
										"propertyOrder": 1
									},
									"Description": {
										"type": "string",
										"propertyOrder": 2
									},
									"Value": {
										"type": "string",
										//"readOnly": "true",
										"propertyOrder": 3
									}
									//,
									//"New value": {
									//	"type": "string",
									//	"propertyOrder": 4
									//}					
								}
							}
						}
					}
				},
				"options": {
					"disable_array_add": true,
					"disable_array_delete": true
				}
			}
		}
	},
	"options": {
		"disable_array_add": true,
		"disable_array_delete": true
	}
}, startval: [
]';
		
		print $jsonSchemaFile $template;
		close $jsonSchemaFile;	
	}; if ($@) {
		die "$sub error: $@";
	} else {
		return "ok";
	}
}

sub DESTROY {
	local($., $@, $!, $^E, $?);
	my ($self) = @_;
	my $sub = (caller(0))[3];
}

1;
