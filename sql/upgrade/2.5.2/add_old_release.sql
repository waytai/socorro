/* This Source Code Form is subject to the terms of the Mozilla Public
 * License, v. 2.0. If a copy of the MPL was not distributed with this
 * file, You can obtain one at http://mozilla.org/MPL/2.0/. */

\set ON_ERROR_STOP 1

CREATE OR REPLACE function add_old_release (
	product_name text,
	new_version text,
	release_type release_enum default 'major',
	release_date DATE DEFAULT current_date,
	is_featured BOOLEAN default FALSE
)
returns boolean
language plpgsql
as $f$
DECLARE last_date DATE;
	featured_count INT;
	new_id INT;
BEGIN

	IF release_type = 'major' THEN
		last_date := release_date + ( 18 * 7 );
	ELSE
		last_date := release_date + ( 9 * 7 );
	END IF;
	
	IF is_featured THEN
		-- check if we already have 4 featured
		SELECT COUNT(*) INTO featured_count
		FROM productdims JOIN product_visibility
			ON productdims.id = product_visibility.productdims_id
		WHERE featured
			AND product = product_name
			AND end_date >= current_date;

		IF featured_count > 4 THEN
			-- too many, drop one
			UPDATE product_visibility
			SET featured = false
			WHERE productdims_id = (
				SELECT id
				FROM productdims
					JOIN product_visibility viz2
						ON productdims.id = viz2.productdims_id
				WHERE product = product_name
					AND featured
					AND end_date >= current_date
				ORDER BY viz2.end_date LIMIT 1
			);
		END IF;
	END IF;
	
    -- now add it
    
    INSERT INTO productdims ( product, version, branch, release, version_sort )
    VALUES ( product_name, new_version, '2.2', release_type, old_version_sort(new_version) )
    RETURNING id
    INTO new_id;
    
    INSERT INTO product_visibility ( productdims_id, start_date, end_date,
    	featured, throttle )
    VALUES ( new_id, release_date, last_date, is_featured, 100 );
    
    RETURN TRUE;
    
END; $f$;
    
    
