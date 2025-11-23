-- Updated match_message_embeddings function that supports searching all conversations
-- when filter_conversation_ids is not provided or is null/empty

CREATE OR REPLACE FUNCTION match_message_embeddings(
  query_embedding vector(768),
  match_count int,
  filter_conversation_ids text[] DEFAULT NULL
)
RETURNS TABLE (
  id uuid,
  conversation_id text,
  chunk_text text,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    me.id,
    me.conversation_id,
    me.chunk_text,
    1 - (me.embedding <=> query_embedding) AS similarity
  FROM message_embeddings me
  WHERE 
    -- Only filter by conversation_ids if provided and not empty
    (filter_conversation_ids IS NULL OR 
     array_length(filter_conversation_ids, 1) IS NULL OR
     me.conversation_id = ANY(filter_conversation_ids))
  ORDER BY me.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;

