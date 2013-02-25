# coding: utf-8

class ProteinSequenceAnnotationStanza < Stanza::Base
  property :title do |tax_id, gene_id|
    "Sequence annotation #{tax_id}:#{gene_id}"
  end

  property :sequence_annotations do |tax_id, gene_id|
    annotations = query(:uniprot, <<-SPARQL)
      PREFIX up: <http://purl.uniprot.org/core/>
      PREFIX taxonomy: <http://purl.uniprot.org/taxonomy/>

      SELECT DISTINCT ?parent_label ?label ?begin_location ?end_location ?comment (GROUP_CONCAT(DISTINCT ?substitution; SEPARATOR=", ") AS ?substitutions) ?seq ?annotation ?feature_identifier
      WHERE {
        ?protein up:organism taxonomy:#{tax_id} ;
                 rdfs:seeAlso <#{uniprot_url_from_togogenome(gene_id)}> ;
                 up:annotation ?annotation .

        ?annotation rdf:type ?type .
        ?type rdfs:label ?label .

        # sequence annotation 直下のtype のラベルを取得(Region, Site, Molecule Processing, Experimental Information)
        ?type rdfs:subClassOf* ?parent_type .
        ?parent_type rdfs:subClassOf up:Sequence_Annotation ;
                     rdfs:label ?parent_label .

        ?annotation up:range ?range .
        OPTIONAL { ?annotation rdfs:comment ?comment . }
        ?range up:begin ?begin_location ;
               up:end ?end_location .

        # description の一部が取得できるが、内容の表示に必要があるのか
        OPTIONAL{
          ?annotation up:substitution ?substitution .
          ?protein up:sequence/rdf:value ?seq .
         }

        OPTIONAL {
          BIND (str(?annotation) as ?feature_identifier) .
          FILTER regex(str(?annotation), 'http://purl.uniprot.org/annotation')
        }
      }
      GROUP BY ?parent_label ?label ?begin_location ?end_location ?comment ?seq ?annotation ?feature_identifier
      ORDER BY ?parent_label ?label ?begin_location ?end_location
    SPARQL

    annotations.map {|hash|
      begin_location, end_location, substitutions, seq = hash.values_at(:begin_location, :end_location, :substitutions, :seq)

      hash.merge(
        location_length:       length(begin_location, end_location),
        position:              position(begin_location, end_location),
        substitution_sequence: substitution_sequence(begin_location, end_location, substitutions, seq)
      )
    }.group_by {|hash|
      hash[:parent_label]
    }.values
  end

  private

  def position(begin_location, end_location)
    (begin_location == end_location) ? begin_location : "#{begin_location}-#{end_location}"
  end

  def length(begin_location, end_location)
    end_location.to_i - begin_location.to_i + 1
  end

  def substitution_sequence(begin_location, end_location, substitutions, seq)
    return if seq.nil?
    seq_array = seq.split(//)
    original = seq_array[begin_location.to_i.pred..end_location.to_i.pred].join
    "#{original} → #{substitutions}: "
  end
end
