class LogicalElement

  attr_accessor :doctype, :id, :dmdid, :admid, :start_page_index, :end_page_index, :part_product, :part_work, :part_key, :level, :parentdoc_work # :label, :type, :volume_uri

  STRCTYPE_LABEL_HASH = {
      "genre"                   => "Genre|Genres",
      "lang"                    => "Sprache|Sprachen",
      "abstract"                => "Abstrakt",
      "acknowledgment"          => "Danksagung",
      "addendum"                => "Addendum",
      "additional"              => "Beilage",
      "advertising"             => "Werbung",
      "annotation"              => "Annotation",
      "announcement"            => "Ankündigung",
      "appendix"                => "Appendix",
      "article"                 => "Artikel",
      "attachedwork"            => "Beigefügtes Werk",
      "beigefuegt"              => "Beigefügt",
      "bibliography"            => "Bibliographie",
      "binding"                 => "Einband",
      "bundle"                  => "Nachlass",
      "chapter"                 => "Kapitel",
      "collectivework"          => "Sammelwerk",
      "comment"                 => "Kommentar",
      "contained_work"          => "Enthaltenes Werk",
      "contents"                => "Inhaltsverzeichnis",
      "corrigenda"              => "Errata",
      "courtdecision"           => "Rechtsentscheidung",
      "cover"                   => "Einband",
      "curriculumvitae"         => "Lebenslauf",
      "dedication"              => "Widmung",
      "epilogue"                => "Epilogue",
      "errata"                  => "Errata",
      "figure"                  => "Abbildung",
      "folder"                  => "Mappe",
      "headword"                => "Stichwort",
      "illustration"            => "Illustration",
      "illustrationdescription" => "Bildbeschreibung",
      "index"                   => "Index",
      "indexabbreviations"      => "Abkürzungsverzeichnis",
      "indexauthor"             => "Index of authors",
      "indexauthors"            => "Autorenverzeichnis",
      "indexchronological"      => "Chronologisches verzeichnis",
      "indexfigures"            => "Abbildungsverzeichnis",
      "indexlocation"           => "Ortsregister",
      "indexlocations"          => "Ortsregister",
      "indexnames"              => "Namensregister",
      "indexofchronology"       => "Index (chronologisch)",
      "indexoverall"            => "Gesamtindex",
      "indexpersons"            => "Personenindex",
      "indexspecial"            => "Spezialverzeichnis",
      "indexsubject"            => "Fachbegriffsregister",
      "indextables"             => "Tabellenverzeichnis",
      "indexvolume"             => "Bandindex",
      "introduction"            => "Einleitung",
      "issue"                   => "Heft",
      "legalcomment"            => "Rechtskommentar",
      "legalnorm"               => "Rechtsnorm",
      "letter"                  => "Brief",
      "lettertoeditor"          => "Brief an den Editor",
      "list"                    => "Liste",
      "listofillustrations"     => "Liste der Abbildungen",
      "listofmaps"              => "Liste der Karten",
      "listofpublications"      => "Publikationsverzeichnis",
      "listoftables"            => "Liste der Tabellen",
      "map"                     => "Karte",
      "message"                 => "Nachricht",
      "miscella"                => "Miszelle",
      "miscelle"                => "Miszelle",
      "monograph"               => "Monograph",
      "multivolume_work"        => "Mehrbändiges Werk",
      "multivolumework"         => "Mehrbändiges Werk",
      "music"                   => "Musik",
      "musical_notation"        => "Noten",
      "notes"                   => "Noten",
      "obituary"                => "Nachruf",
      "other"                   => "Sonstiges",
      "otherdocstrct"           => "Sonstiges",
      "partofwork"              => "Teilwerk",
      "periodical"              => "Zeitschrift",
      "periodicalissue"         => "Zeitschriftenheft",
      "periodicalpart"          => "Zeitschriftenteil",
      "periodicalvolume"        => "Zeitschriftenband",
      "poem"                    => "Gedicht",
      "preface"                 => "Vorwort",
      "prepage"                 => "Deckblatt",
      "remarks"                 => "Anmerkungen",
      "review"                  => "Rezension",
      "section"                 => "Abschnitt",
      "sheetmusic"              => "Musik",
      "singlemap"               => "Einzelne Karte",
      "supplement"              => "Beilage",
      "table"                   => "Tabelle, Liste",
      "tabledescription"        => "Tabelle der Beschreibungen",
      "tablelist"               => "Tabelle, Liste",
      "tableofabbreviations"    => "Abkürzungsverzeichnis",
      "tableofcontents"         => "Inhaltsverzeichnis",
      "tableofliteraturerefs"   => "Literaturverzeichnis",
      "textsection"             => "Textabschnitt",
      "theses"                  => "Dissertation",
      "title_page"              => "Titelseite",
      "titlepage"               => "Titelseite",
      "unit"                    => "Teil",
      "volume"                  => "Teil eines mehrbändigen Werkes",
      "werk_beigefuegt"         => "Beigefügtes Werk",
      "werk"                    => "Werk"
  }

  STRCTYPE_HASH = {
      "monograph"                 => "monograph",

      "periodical"                => "periodical",

      "periodicalvolume"          => "volume",
      "periodical_volume"          => "volume",
      "periodicalissue"           => "periodical_issue", # todo mapping ?
      "periodical_issue"           => "periodical_issue", # todo mapping ?
      "periodicalpart"            => "periodical_part", # todo mapping ?
      "periodical_part"            => "periodical_part", # todo mapping ?

      "multivolumework"           => "multivolume_work",
      "multivolume_work"          => "multivolume_work",
      "volume"                    => "volume",


      "contained_work"            => "contained_work", # todo mapping ?
      "containedwork"             => "contained_work", # todo mapping ?


      "bundle"                    => "bundle",
      "folder"                    => "folder",

      "manuscript"                => "manuscript",


      "cover"                     => "cover", # todo mapping ?
      "prepage"                   => "prepage", # todo mapping ?


      "title_page"                => "title_page",
      "titlepage"                 => "title_page",


      "chapter"                   => "chapter", # todo mapping ?

      "section"                   => "section",

      "tableofcontents"           => "contents",
      "table_of_contents"           => "contents",

      "binding"                   => "binding",

      "dedicationforewordintro"   => "dedication_foreword_intro", # todo mapping ?
      "dedication_foreword_intro"   => "dedication_foreword_intro", # todo mapping ?

      "dedication"                => "dedication",

      "tablelist"                 => "table_list", # todo mapping ?
      "table_list"                 => "table_list", # todo mapping ?

      "index"                     => "index",

      "indexspecial"              => "index_special", # todo mapping ?
      "index_special"              => "index_special", # todo mapping ?

      "indexlocation"             => "index_location", # todo mapping ?
      "index_location"             => "index_location", # todo mapping ?

      "article"                   => "article",

      "illustration"              => "illustration",

      "contents"                  => "contents",


      "errata"                    => "corrigenda",
      "corrigenda"                => "corrigenda",

      "journal"                   => "periodical", # todo ?

      "figure"                    => "figure", # todo mapping ?


      "preface"                   => "preface",

      "textsection"               => "text_section", # todo mapping ?
      "text_section"               => "text_section", # todo mapping ?


      "verse"                     => "verse", # todo mapping ?
      "appendix"                  => "appendix", # todo mapping ?
      "remarks"                   => "remarks", # todo mapping ?


      "imprint"                   => "imprint", # todo mapping ?


      "map"                       => "map",

      "issue"                     => "issue", # todo mapping ?

      "introduction"              => "introduction", # todo mapping ?

      "unit"                      => "unit", # todo mapping ?

      "advertising"               => "advertising", # todo mapping ?
      "announcementadvertisement" => "announcement_advertisement", # todo mapping ?
      "announcement_advertisement" => "announcement_advertisement", # todo mapping ?


      "table"                     => "table",

      "illustrationdescription"   => "illustration_description", # todo mapping ?
      "illustration_description"   => "illustration_description", # todo mapping ?

      "review"                    => "review", # todo mapping ?

      "engravedtitlepage"        => "engraved_titlepage",
      "engraved_titlepage"        => "engraved_titlepage",

      "message"                   => "message", # todo mapping ?

      "additional"                => "additional", # todo mapping ?

      "indexpersons"              => "index_persons", # todo mapping ?
      "index_persons"              => "index_persons", # todo mapping ?

      "indexsubject"              => "index_subject", # todo mapping ?
      "index_subject"              => "index_subject", # todo mapping ?

      "entry"                     => "entry", # todo mapping ?
      "addendum"                  => "addendum", # todo mapping ?

      "tableofliteraturerefs"     => "table_of_literature_refs", # todo mapping ?
      "table_of_literature_refs"     => "table_of_literature_refs", # todo mapping ?

      "indexoverall"              => "index_overall", # todo mapping ?
      "index_overall"              => "index_overall", # todo mapping ?

      "attachedwork"              => "attached_work", # todo mapping ?
      "attached_work"              => "attached_work", # todo mapping ?

      "announcement"              => "announcement", # todo mapping ?

      "indexauthor"               => "index_author", # todo mapping ?
      "index_author"               => "index_author", # todo mapping ?

      "letter"                    => "letter", # todo mapping ?
      "epilogue"                  => "epilogue", # todo mapping ?
      "list"                      => "list", # todo mapping ?
      "title"                     => "title", # todo mapping ?

      "partofwork"                => "part_of_work", # todo mapping ?
      "part_of_work"                => "part_of_work", # todo mapping ?

      "imprintcolophon"           => "imprint_colophon", # todo mapping ?
      "imprint_colophon"           => "imprint_colophon", # todo mapping ?
      "colophon"                  => "colophon",

      "obituary"                  => "obituary", # todo mapping ?

      "other"                     => "other", # todo mapping ?

      "otherdocstrct"             => "other_docstrct", # todo mapping ?
      "other_doc_strct"             => "other_docstrct", # todo mapping ?

      "otherdocstruct"            => "other_docstrct", # todo mapping ?
      "other_doc_struct"            => "other_docstrct", # todo mapping ?

      "miscellany"                => "miscellany", # todo mapping ?
      "miscella"                  => "miscellany", # todo mapping ?


      "music"                     => "music", # todo mapping ?

      "sheetmusic"                => "sheet_music", # todo mapping ?
      "sheet_music"                => "sheet_music", # todo mapping ?

      "musicalnotation"          => "musical_notation",
      "musical_notation"          => "musical_notation",

      "supplement"                => "supplement", # todo mapping ?

      "acknowledgment"            => "acknowledgment", # todo mapping ?
      "bibliography"              => "bibliography", # todo mapping ?

      "abstract"                  => "abstract", # todo mapping ?

      "curriculumvitae"           => "curriculum_vitae", # todo mapping ?
      "curriculum_vitae"           => "curriculum_vitae", # todo mapping ?

      "tableofabbreviations"      => "table_of_abbreviations", # todo mapping ?
      "table_of_abbreviations"      => "table_of_abbreviations", # todo mapping ?


      "headword"                  => "headword", # todo mapping ?
      "theses"                    => "theses", # todo mapping ?

      "listofpublications"        => "list_of_publications", # todo mapping ?
      "list_of_publications"        => "list_of_publications", # todo mapping ?

      "tabledescription"          => "table_description", # todo mapping ?
      "table_description"          => "table_description" # todo mapping ?

  }

  def type=(type)
    t = STRCTYPE_HASH[type.downcase]
    t = type if t == nil

    @type = t
  end

  def type
    @type
  end


  def label=(label)
    l = STRCTYPE_LABEL_HASH[label.downcase]
    l = label if l == nil

    @label = l
  end

  def label
    @label
  end



end