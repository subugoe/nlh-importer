class LogicalElement

  attr_accessor :doctype, :id, :label, :dmdid, :admid, :start_page_index, :end_page_index, :part_product, :part_work, :part_key, :level, :parentdoc_work # :volume_uri


  STRCTYPE_HASH = {
      "monograph"                 => "monograph",
      "Monograph"                 => "monograph",

      "periodical"                => "periodical",
      "Periodical"                => "periodical",

      "periodicalvolume"          => "volume",
      "PeriodicalVolume"          => "volume",
      "PeriodicalIssue"           => "periodical_issue",# todo mapping ?
      "PeriodicalPart"            => "periodical_part",# todo mapping ?

      "MultivolumeWork"           => "multivolume_work",
      "multivolumework"           => "multivolume_work",
      "multivolume_work"          => "multivolume_work",
      "MultiVolumeWork"           => "multivolume_work",
      "volume"                    => "volume",
      "Volume"                    => "volume",


      "contained_work"            => "contained_work",# todo mapping ?
      "ContainedWork"             => "contained_work",# todo mapping ?


      "bundle"                    => "bundle",
      "folder"                    => "folder",

      "manuscript"                => "manuscript",


      "Cover"                     => "cover", # todo mapping ?
      "cover"                     => "cover",# todo mapping ?
      "Prepage"                   => "prepage",# todo mapping ?


      "title_page"                => "title_page",
      "TitlePage"                 => "title_page",


      "Chapter"                   => "chapter",# todo mapping ?
      "chapter"                   => "chapter",# todo mapping ?

      "Section"                   => "section",
      "section"                   => "section",

      "TableOfContents"           => "contents",

      "binding"                   => "binding",

      "DedicationForewordIntro"   => "dedication_foreword_intro",# todo mapping ?

      "dedication"                => "dedication",
      "Dedication"                => "dedication",

      "TableList"                 => "table_list",# todo mapping ?
      "Index"                     => "index",
      "index"                     => "index",
      "IndexSpecial"              => "index_special",# todo mapping ?
      "IndexLocation"             => "index_location",# todo mapping ?

      "Article"                   => "article",

      "Illustration"              => "illustration",
      "illustration"              => "illustration",

      "contents"                  => "contents",


      "Errata"                    => "corrigenda",
      "corrigenda"                => "corrigenda",

      "Journal"                   => "periodical", # todo ?
      "journal"                   => "periodical", # todo ?

      "Figure"                    => "figure",# todo mapping ?


      "preface"                   => "preface",
      "Preface"                   => "preface",

      "TextSection"               => "text_section",# todo mapping ?



      "verse"                     => "verse",# todo mapping ?
      "Appendix"                  => "appendix",# todo mapping ?
      "Remarks"                   => "remarks",# todo mapping ?



      "Imprint"                   => "imprint",# todo mapping ?



      "Map"                       => "map",
      "map"                       => "map",

      "Issue"                     => "issue",# todo mapping ?
      "issue"                     => "issue",# todo mapping ?

      "Introduction"              => "introduction",# todo mapping ?

      "Unit"                      => "unit",# todo mapping ?

      "Advertising"               => "advertising",# todo mapping ?
      "AnnouncementAdvertisement" => "announcement_advertisement",# todo mapping ?


      "article"                   => "article",# todo mapping ?


      "Table"                     => "table",
      "table"                     => "table",

      "IllustrationDescription"   => "illustration_description",# todo mapping ?
      "Review"                    => "review",# todo mapping ?

      "engraved_titlepage"        => "engraved_titlepage",

      "Message"                   => "message",# todo mapping ?

      "additional"                => "additional",# todo mapping ?

      "IndexPersons"              => "index_persons",# todo mapping ?
      "IndexSubject"              => "index_subject",# todo mapping ?
      "Entry"                     => "entry",# todo mapping ?
      "Addendum"                  => "addendum",# todo mapping ?
      "TableOfLiteratureRefs"     => "table_of_literature_refs",# todo mapping ?
      "IndexOverall"              => "index_overall",# todo mapping ?
      "AttachedWork"              => "attached_work",# todo mapping ?

      "Announcement"              => "announcement",# todo mapping ?
      "IndexAuthor"               => "index_author",# todo mapping ?
      "Letter"                    => "letter",# todo mapping ?
      "Epilogue"                  => "epilogue",# todo mapping ?
      "List"                      => "list",# todo mapping ?
      "Title"                     => "title",# todo mapping ?
      "PartOfWork"                => "part_of_work",# todo mapping ?

      "ImprintColophon"           => "imprint_colophon",# todo mapping ?
      "colophon"                  => "colophon",

      "Obituary"                  => "obituary",# todo mapping ?


      "other"                     => "other",# todo mapping ?
      "Other"                     => "other",# todo mapping ?
      "OtherDocStrct"             => "other_docstrct",# todo mapping ?
      "OtherDocStruct"            => "other_docstrct",# todo mapping ?

      "Miscellany"                => "miscellany",# todo mapping ?
      "Miscella"                  => "miscellany",# todo mapping ?


      "Music"                     => "music",# todo mapping ?
      "SheetMusic"                => "sheet_music",# todo mapping ?
      "musical_notation"          => "musical_notation",

      "Supplement"                => "supplement",# todo mapping ?
      "Acknowledgment"            => "acknowledgment",# todo mapping ?
      "Bibliography"              => "bibliography",# todo mapping ?

      "Abstract"                  => "abstract",# todo mapping ?
      "CurriculumVitae"           => "curriculum_vitae",# todo mapping ?
      "TableOfAbbreviations"      => "table_of_abbreviations",# todo mapping ?


      "Headword"                  => "headword",# todo mapping ?
      "Theses"                    => "theses",# todo mapping ?
      "ListOfPublications"        => "list_of_publications",# todo mapping ?
      "TableDescription"          => "table_description"# todo mapping ?

  }

  def type(type)
    t = STRCTYPE_HASH[type]
    t = type if t == nil

    @type = t
  end

  def type
    @type
  end


end