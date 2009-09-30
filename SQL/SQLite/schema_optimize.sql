--
-- Recreate the contributor_album table to ensure it is accurate (bug 4882).
-- This is done here as it is faster to do in sql than in the server.
--

DELETE FROM contributor_album;

INSERT INTO contributor_album (role,contributor,album) SELECT DISTINCT role,contributor,album FROM contributor_track,tracks where tracks.id=contributor_track.track;

