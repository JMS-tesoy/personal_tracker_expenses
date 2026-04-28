


SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "public"."rls_auto_enable"() RETURNS "event_trigger"
    LANGUAGE "plpgsql" SECURITY DEFINER
    SET "search_path" TO 'pg_catalog'
    AS $$
DECLARE
  cmd record;
BEGIN
  FOR cmd IN
    SELECT *
    FROM pg_event_trigger_ddl_commands()
    WHERE command_tag IN ('CREATE TABLE', 'CREATE TABLE AS', 'SELECT INTO')
      AND object_type IN ('table','partitioned table')
  LOOP
     IF cmd.schema_name IS NOT NULL AND cmd.schema_name IN ('public') AND cmd.schema_name NOT IN ('pg_catalog','information_schema') AND cmd.schema_name NOT LIKE 'pg_toast%' AND cmd.schema_name NOT LIKE 'pg_temp%' THEN
      BEGIN
        EXECUTE format('alter table if exists %s enable row level security', cmd.object_identity);
        RAISE LOG 'rls_auto_enable: enabled RLS on %', cmd.object_identity;
      EXCEPTION
        WHEN OTHERS THEN
          RAISE LOG 'rls_auto_enable: failed to enable RLS on %', cmd.object_identity;
      END;
     ELSE
        RAISE LOG 'rls_auto_enable: skip % (either system schema or not in enforced list: %.)', cmd.object_identity, cmd.schema_name;
     END IF;
  END LOOP;
END;
$$;


ALTER FUNCTION "public"."rls_auto_enable"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."set_reminders_updated_at"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
begin
  new.updated_at = now();
  return new;
end;
$$;


ALTER FUNCTION "public"."set_reminders_updated_at"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."activity_logs" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "actor_id" "uuid",
    "target_type" "text" NOT NULL,
    "target_id" "uuid",
    "person_id" "uuid",
    "action" "text" NOT NULL,
    "title" "text" NOT NULL,
    "description" "text",
    "metadata" "jsonb" DEFAULT '{}'::"jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."activity_logs" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."attachments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "related_type" "text" NOT NULL,
    "related_id" "uuid" NOT NULL,
    "file_url" "text" NOT NULL,
    "file_name" "text",
    "uploaded_by_person_id" "uuid",
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid",
    "uploaded_by_device_id" "uuid"
);


ALTER TABLE "public"."attachments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bill_comments" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "bill_id" "uuid" NOT NULL,
    "person_id" "uuid",
    "message" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone
);


ALTER TABLE "public"."bill_comments" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."bills" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "amount" numeric DEFAULT 0 NOT NULL,
    "due_day" integer DEFAULT 1 NOT NULL,
    "assigned_to" "text",
    "paid_by" "text",
    "paid_on" "date",
    "payment_method" "text" DEFAULT ''::"text" NOT NULL,
    "status" "text" DEFAULT 'unpaid'::"text" NOT NULL,
    "notes" "text",
    "remarks" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "assigned_person_id" "uuid",
    "paid_by_person_id" "uuid",
    "user_id" "uuid",
    "paid_by_person_ids" "uuid"[] DEFAULT '{}'::"uuid"[] NOT NULL,
    CONSTRAINT "bills_due_day_check" CHECK ((("due_day" >= 1) AND ("due_day" <= 31))),
    CONSTRAINT "bills_status_check" CHECK (("status" = ANY (ARRAY['unpaid'::"text", 'paid'::"text", 'overdue'::"text"])))
);


ALTER TABLE "public"."bills" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."categories" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "type" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "user_id" "uuid"
);


ALTER TABLE "public"."categories" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."loan_payment_contributions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "loan_id" "uuid" NOT NULL,
    "person_id" "uuid" NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "paid_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "loan_payment_contributions_amount_check" CHECK (("amount" > (0)::numeric))
);


ALTER TABLE "public"."loan_payment_contributions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."loans" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "lender" "text",
    "original_amount" numeric(12,2) NOT NULL,
    "remaining_balance" numeric(12,2) NOT NULL,
    "monthly_installment" numeric(12,2) NOT NULL,
    "due_day" integer NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "notes" "text",
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "total_cycles" integer DEFAULT 1 NOT NULL,
    "paid_cycles" integer DEFAULT 0 NOT NULL,
    "start_date" "date",
    "next_due_date" "date",
    "total_paydays" integer DEFAULT 2 NOT NULL,
    "paid_paydays" integer DEFAULT 0 NOT NULL,
    "user_id" "uuid",
    CONSTRAINT "loans_due_day_check" CHECK ((("due_day" >= 1) AND ("due_day" <= 31))),
    CONSTRAINT "loans_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'paid'::"text", 'overdue'::"text"])))
);


ALTER TABLE "public"."loans" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."people" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "name" "text" NOT NULL,
    "avatar_url" "text",
    "role" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "user_id" "uuid"
);


ALTER TABLE "public"."people" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."people_groups" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "name" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."people_groups" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."reminders" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "target_type" "text" DEFAULT 'general'::"text" NOT NULL,
    "target_id" "uuid",
    "person_id" "uuid",
    "title" "text" NOT NULL,
    "message" "text",
    "due_at" timestamp with time zone,
    "remind_at" timestamp with time zone NOT NULL,
    "repeat_type" "text" DEFAULT 'none'::"text" NOT NULL,
    "status" "text" DEFAULT 'active'::"text" NOT NULL,
    "notification_id" integer,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "updated_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "reminders_repeat_type_check" CHECK (("repeat_type" = ANY (ARRAY['none'::"text", 'daily'::"text", 'weekly'::"text", 'monthly'::"text"]))),
    CONSTRAINT "reminders_status_check" CHECK (("status" = ANY (ARRAY['active'::"text", 'completed'::"text", 'cancelled'::"text"]))),
    CONSTRAINT "reminders_target_type_check" CHECK (("target_type" = ANY (ARRAY['general'::"text", 'bill'::"text", 'loan'::"text", 'person'::"text", 'payment'::"text"])))
);


ALTER TABLE "public"."reminders" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."transactions" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "amount" numeric(12,2) NOT NULL,
    "type" "text" NOT NULL,
    "category" "text" NOT NULL,
    "payment_method" "text" NOT NULL,
    "note" "text",
    "transaction_date" timestamp with time zone DEFAULT "now"() NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "category_id" "uuid",
    "user_id" "uuid",
    "is_archived" boolean DEFAULT false NOT NULL
);


ALTER TABLE "public"."transactions" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."user_devices" (
    "id" "uuid" DEFAULT "gen_random_uuid"() NOT NULL,
    "user_id" "uuid" NOT NULL,
    "device_instance_id" "text" NOT NULL,
    "device_name" "text",
    "platform" "text",
    "os_version" "text",
    "app_version" "text",
    "app_build_number" "text",
    "first_seen_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    "last_seen_at" timestamp with time zone DEFAULT "now"() NOT NULL
);


ALTER TABLE "public"."user_devices" OWNER TO "postgres";


ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "activity_logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."attachments"
    ADD CONSTRAINT "attachments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bill_comments"
    ADD CONSTRAINT "bill_comments_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "bills_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_name_key" UNIQUE ("name");



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."loan_payment_contributions"
    ADD CONSTRAINT "loan_payment_contributions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."loans"
    ADD CONSTRAINT "loans_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."people_groups"
    ADD CONSTRAINT "people_groups_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."people"
    ADD CONSTRAINT "people_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."reminders"
    ADD CONSTRAINT "reminders_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_devices"
    ADD CONSTRAINT "user_devices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."user_devices"
    ADD CONSTRAINT "user_devices_user_id_device_instance_id_key" UNIQUE ("user_id", "device_instance_id");



CREATE INDEX "activity_logs_user_created_idx" ON "public"."activity_logs" USING "btree" ("user_id", "created_at" DESC);



CREATE INDEX "attachments_uploaded_by_device_id_idx" ON "public"."attachments" USING "btree" ("uploaded_by_device_id");



CREATE INDEX "attachments_user_id_related_idx" ON "public"."attachments" USING "btree" ("user_id", "related_type", "related_id");



CREATE INDEX "bill_comments_bill_id_idx" ON "public"."bill_comments" USING "btree" ("bill_id");



CREATE INDEX "bill_comments_created_at_idx" ON "public"."bill_comments" USING "btree" ("created_at");



CREATE INDEX "bill_comments_person_id_idx" ON "public"."bill_comments" USING "btree" ("person_id");



CREATE INDEX "bill_comments_user_id_idx" ON "public"."bill_comments" USING "btree" ("user_id");



CREATE INDEX "bills_paid_by_person_ids_idx" ON "public"."bills" USING "gin" ("paid_by_person_ids");



CREATE INDEX "bills_user_id_due_day_idx" ON "public"."bills" USING "btree" ("user_id", "due_day");



CREATE INDEX "bills_user_id_status_idx" ON "public"."bills" USING "btree" ("user_id", "status");



CREATE INDEX "categories_user_id_type_idx" ON "public"."categories" USING "btree" ("user_id", "type");



CREATE INDEX "idx_activity_logs_actor_id" ON "public"."activity_logs" USING "btree" ("actor_id");



CREATE INDEX "idx_activity_logs_created_at" ON "public"."activity_logs" USING "btree" ("created_at" DESC);



CREATE INDEX "idx_activity_logs_person_id" ON "public"."activity_logs" USING "btree" ("person_id");



CREATE INDEX "idx_activity_logs_target" ON "public"."activity_logs" USING "btree" ("target_type", "target_id");



CREATE INDEX "idx_activity_logs_user_id" ON "public"."activity_logs" USING "btree" ("user_id");



CREATE INDEX "loan_payment_contributions_loan_id_idx" ON "public"."loan_payment_contributions" USING "btree" ("loan_id");



CREATE INDEX "loan_payment_contributions_user_loan_idx" ON "public"."loan_payment_contributions" USING "btree" ("user_id", "loan_id");



CREATE INDEX "loans_user_id_next_due_date_idx" ON "public"."loans" USING "btree" ("user_id", "next_due_date");



CREATE UNIQUE INDEX "people_groups_user_name_idx" ON "public"."people_groups" USING "btree" ("user_id", "lower"("name"));



CREATE INDEX "people_user_id_idx" ON "public"."people" USING "btree" ("user_id");



CREATE UNIQUE INDEX "people_user_id_name_unique_idx" ON "public"."people" USING "btree" ("user_id", "lower"("btrim"("name")));



CREATE INDEX "reminders_remind_at_idx" ON "public"."reminders" USING "btree" ("remind_at");



CREATE INDEX "reminders_status_idx" ON "public"."reminders" USING "btree" ("status");



CREATE INDEX "reminders_target_idx" ON "public"."reminders" USING "btree" ("target_type", "target_id");



CREATE INDEX "reminders_user_id_idx" ON "public"."reminders" USING "btree" ("user_id");



CREATE INDEX "transactions_user_id_archived_date_idx" ON "public"."transactions" USING "btree" ("user_id", "is_archived", "transaction_date" DESC);



CREATE INDEX "transactions_user_id_date_idx" ON "public"."transactions" USING "btree" ("user_id", "transaction_date" DESC);



CREATE INDEX "user_devices_user_id_idx" ON "public"."user_devices" USING "btree" ("user_id");



CREATE OR REPLACE TRIGGER "reminders_updated_at" BEFORE UPDATE ON "public"."reminders" FOR EACH ROW EXECUTE FUNCTION "public"."set_reminders_updated_at"();



ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "activity_logs_actor_id_fkey" FOREIGN KEY ("actor_id") REFERENCES "auth"."users"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."activity_logs"
    ADD CONSTRAINT "activity_logs_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."attachments"
    ADD CONSTRAINT "attachments_uploaded_by_device_id_fkey" FOREIGN KEY ("uploaded_by_device_id") REFERENCES "public"."user_devices"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."attachments"
    ADD CONSTRAINT "attachments_uploaded_by_person_id_fkey" FOREIGN KEY ("uploaded_by_person_id") REFERENCES "public"."people"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."attachments"
    ADD CONSTRAINT "attachments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bill_comments"
    ADD CONSTRAINT "bill_comments_bill_id_fkey" FOREIGN KEY ("bill_id") REFERENCES "public"."bills"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bill_comments"
    ADD CONSTRAINT "bill_comments_person_id_fkey" FOREIGN KEY ("person_id") REFERENCES "public"."people"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bill_comments"
    ADD CONSTRAINT "bill_comments_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "bills_assigned_person_id_fkey" FOREIGN KEY ("assigned_person_id") REFERENCES "public"."people"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "bills_paid_by_person_id_fkey" FOREIGN KEY ("paid_by_person_id") REFERENCES "public"."people"("id") ON DELETE SET NULL;



ALTER TABLE ONLY "public"."bills"
    ADD CONSTRAINT "bills_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."categories"
    ADD CONSTRAINT "categories_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."loan_payment_contributions"
    ADD CONSTRAINT "loan_payment_contributions_loan_id_fkey" FOREIGN KEY ("loan_id") REFERENCES "public"."loans"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."loan_payment_contributions"
    ADD CONSTRAINT "loan_payment_contributions_person_id_fkey" FOREIGN KEY ("person_id") REFERENCES "public"."people"("id") ON DELETE RESTRICT;



ALTER TABLE ONLY "public"."loan_payment_contributions"
    ADD CONSTRAINT "loan_payment_contributions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."loans"
    ADD CONSTRAINT "loans_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."people_groups"
    ADD CONSTRAINT "people_groups_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."people"
    ADD CONSTRAINT "people_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."reminders"
    ADD CONSTRAINT "reminders_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."transactions"
    ADD CONSTRAINT "transactions_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."user_devices"
    ADD CONSTRAINT "user_devices_user_id_fkey" FOREIGN KEY ("user_id") REFERENCES "auth"."users"("id") ON DELETE CASCADE;



CREATE POLICY "Allow all categories for now" ON "public"."categories" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow all for authenticated" ON "public"."attachments" USING (true) WITH CHECK (true);



CREATE POLICY "Allow all for authenticated" ON "public"."people" USING (true) WITH CHECK (true);



CREATE POLICY "Allow all for now" ON "public"."bills" USING (true) WITH CHECK (true);



CREATE POLICY "Allow all for now" ON "public"."transactions" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow all loans for now" ON "public"."loans" TO "anon" USING (true) WITH CHECK (true);



CREATE POLICY "Allow anon insert attachments" ON "public"."attachments" FOR INSERT TO "anon" WITH CHECK (("related_type" = 'bill'::"text"));



CREATE POLICY "Allow anon read bill attachments" ON "public"."attachments" FOR SELECT TO "anon" USING (("related_type" = 'bill'::"text"));



CREATE POLICY "Users can insert own activity logs" ON "public"."activity_logs" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users can view own activity logs" ON "public"."activity_logs" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users delete own reminders" ON "public"."reminders" FOR DELETE USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users insert own reminders" ON "public"."reminders" FOR INSERT WITH CHECK (("auth"."uid"() = "user_id"));



CREATE POLICY "Users select own reminders" ON "public"."reminders" FOR SELECT USING (("auth"."uid"() = "user_id"));



CREATE POLICY "Users update own reminders" ON "public"."reminders" FOR UPDATE USING (("auth"."uid"() = "user_id"));



ALTER TABLE "public"."activity_logs" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."attachments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "attachments_owner_delete" ON "public"."attachments" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "attachments_owner_insert" ON "public"."attachments" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "attachments_owner_select" ON "public"."attachments" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "attachments_owner_update" ON "public"."attachments" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."bill_comments" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "bill_comments_owner_insert" ON "public"."bill_comments" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "bill_comments_owner_select" ON "public"."bill_comments" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "bill_comments_owner_update" ON "public"."bill_comments" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."bills" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "bills_owner_insert" ON "public"."bills" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "bills_owner_select" ON "public"."bills" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "bills_owner_update" ON "public"."bills" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."categories" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "categories_owner_delete" ON "public"."categories" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "categories_owner_insert" ON "public"."categories" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "categories_owner_select" ON "public"."categories" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "categories_owner_update" ON "public"."categories" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."loan_payment_contributions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "loan_payment_contributions_owner_insert" ON "public"."loan_payment_contributions" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "loan_payment_contributions_owner_select" ON "public"."loan_payment_contributions" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."loans" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "loans_owner_delete" ON "public"."loans" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "loans_owner_insert" ON "public"."loans" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "loans_owner_select" ON "public"."loans" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "loans_owner_update" ON "public"."loans" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."people" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."people_groups" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "people_groups_owner_delete" ON "public"."people_groups" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "people_groups_owner_insert" ON "public"."people_groups" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "people_groups_owner_select" ON "public"."people_groups" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "people_groups_owner_update" ON "public"."people_groups" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "people_owner_delete" ON "public"."people" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "people_owner_insert" ON "public"."people" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "people_owner_select" ON "public"."people" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "people_owner_update" ON "public"."people" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."reminders" ENABLE ROW LEVEL SECURITY;


ALTER TABLE "public"."transactions" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "transactions_owner_delete" ON "public"."transactions" FOR DELETE TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "transactions_owner_insert" ON "public"."transactions" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "transactions_owner_select" ON "public"."transactions" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "transactions_owner_update" ON "public"."transactions" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));



ALTER TABLE "public"."user_devices" ENABLE ROW LEVEL SECURITY;


CREATE POLICY "user_devices_owner_insert" ON "public"."user_devices" FOR INSERT TO "authenticated" WITH CHECK (("user_id" = "auth"."uid"()));



CREATE POLICY "user_devices_owner_select" ON "public"."user_devices" FOR SELECT TO "authenticated" USING (("user_id" = "auth"."uid"()));



CREATE POLICY "user_devices_owner_update" ON "public"."user_devices" FOR UPDATE TO "authenticated" USING (("user_id" = "auth"."uid"())) WITH CHECK (("user_id" = "auth"."uid"()));





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";






ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."bills";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."loans";



ALTER PUBLICATION "supabase_realtime" ADD TABLE ONLY "public"."transactions";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";






















































































































































GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "anon";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."rls_auto_enable"() TO "service_role";



GRANT ALL ON FUNCTION "public"."set_reminders_updated_at"() TO "anon";
GRANT ALL ON FUNCTION "public"."set_reminders_updated_at"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."set_reminders_updated_at"() TO "service_role";


















GRANT ALL ON TABLE "public"."activity_logs" TO "anon";
GRANT ALL ON TABLE "public"."activity_logs" TO "authenticated";
GRANT ALL ON TABLE "public"."activity_logs" TO "service_role";



GRANT ALL ON TABLE "public"."attachments" TO "anon";
GRANT ALL ON TABLE "public"."attachments" TO "authenticated";
GRANT ALL ON TABLE "public"."attachments" TO "service_role";



GRANT ALL ON TABLE "public"."bill_comments" TO "anon";
GRANT ALL ON TABLE "public"."bill_comments" TO "authenticated";
GRANT ALL ON TABLE "public"."bill_comments" TO "service_role";



GRANT ALL ON TABLE "public"."bills" TO "anon";
GRANT ALL ON TABLE "public"."bills" TO "authenticated";
GRANT ALL ON TABLE "public"."bills" TO "service_role";



GRANT ALL ON TABLE "public"."categories" TO "anon";
GRANT ALL ON TABLE "public"."categories" TO "authenticated";
GRANT ALL ON TABLE "public"."categories" TO "service_role";



GRANT ALL ON TABLE "public"."loan_payment_contributions" TO "anon";
GRANT ALL ON TABLE "public"."loan_payment_contributions" TO "authenticated";
GRANT ALL ON TABLE "public"."loan_payment_contributions" TO "service_role";



GRANT ALL ON TABLE "public"."loans" TO "anon";
GRANT ALL ON TABLE "public"."loans" TO "authenticated";
GRANT ALL ON TABLE "public"."loans" TO "service_role";



GRANT ALL ON TABLE "public"."people" TO "anon";
GRANT ALL ON TABLE "public"."people" TO "authenticated";
GRANT ALL ON TABLE "public"."people" TO "service_role";



GRANT ALL ON TABLE "public"."people_groups" TO "anon";
GRANT ALL ON TABLE "public"."people_groups" TO "authenticated";
GRANT ALL ON TABLE "public"."people_groups" TO "service_role";



GRANT ALL ON TABLE "public"."reminders" TO "anon";
GRANT ALL ON TABLE "public"."reminders" TO "authenticated";
GRANT ALL ON TABLE "public"."reminders" TO "service_role";



GRANT ALL ON TABLE "public"."transactions" TO "anon";
GRANT ALL ON TABLE "public"."transactions" TO "authenticated";
GRANT ALL ON TABLE "public"."transactions" TO "service_role";



GRANT ALL ON TABLE "public"."user_devices" TO "anon";
GRANT ALL ON TABLE "public"."user_devices" TO "authenticated";
GRANT ALL ON TABLE "public"."user_devices" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";



































