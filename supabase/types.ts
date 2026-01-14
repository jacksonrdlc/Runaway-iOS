export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "13.0.5"
  }
  graphql_public: {
    Tables: {
      [_ in never]: never
    }
    Views: {
      [_ in never]: never
    }
    Functions: {
      graphql: {
        Args: {
          extensions?: Json
          operationName?: string
          query?: string
          variables?: Json
        }
        Returns: Json
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
  public: {
    Tables: {
      activities: {
        Row: {
          activity_date: string
          activity_type_id: number | null
          apparent_temperature: number | null
          athlete_id: number
          auth_user_id: string | null
          average_cadence: number | null
          average_elapsed_speed: number | null
          average_flow: number | null
          average_grade: number | null
          average_grade_adjusted_pace: number | null
          average_heart_rate: number | null
          average_negative_grade: number | null
          average_positive_grade: number | null
          average_speed: number | null
          average_temperature: number | null
          average_watts: number | null
          calories: number | null
          carbon_saved: number | null
          cloud_cover: number | null
          commute: boolean | null
          competition: boolean | null
          created_at: string | null
          description: string | null
          device_name: string | null
          device_watts: boolean | null
          dewpoint: number | null
          dirt_distance: number | null
          distance: number | null
          elapsed_time: number | null
          elevation_gain: number | null
          elevation_high: number | null
          elevation_loss: number | null
          elevation_low: number | null
          end_latitude: number | null
          end_longitude: number | null
          external_id: string | null
          filename: string | null
          flagged: boolean | null
          for_a_cause: boolean | null
          from_upload: boolean | null
          gear_id: string | null
          grade_adjusted_distance: number | null
          has_heartrate: boolean | null
          humidity: number | null
          id: number
          intensity: number | null
          jump_count: number | null
          long_run: boolean | null
          manual: boolean | null
          map_polyline: string | null
          map_summary_polyline: string | null
          max_cadence: number | null
          max_grade: number | null
          max_heart_rate: number | null
          max_speed: number | null
          max_temperature: number | null
          max_watts: number | null
          moving_time: number | null
          name: string | null
          newly_explored_dirt_distance: number | null
          newly_explored_distance: number | null
          perceived_exertion: number | null
          pool_length: number | null
          precipitation_intensity: number | null
          precipitation_probability: number | null
          precipitation_type: string | null
          private: boolean | null
          raw_data: Json | null
          relative_effort: number | null
          resource_state: number | null
          source: string | null
          start_latitude: number | null
          start_longitude: number | null
          start_time: string | null
          timer_time: number | null
          total_cycles: number | null
          total_grit: number | null
          total_steps: number | null
          total_work: number | null
          trainer: boolean | null
          training_load: number | null
          updated_at: string | null
          uv_index: number | null
          weather_condition: string | null
          weather_ozone: number | null
          weather_pressure: number | null
          weather_visibility: number | null
          weighted_average_watts: number | null
          wind_bearing: number | null
          wind_gust: number | null
          wind_speed: number | null
          with_pet: boolean | null
        }
        Insert: {
          activity_date: string
          activity_type_id?: number | null
          apparent_temperature?: number | null
          athlete_id: number
          auth_user_id?: string | null
          average_cadence?: number | null
          average_elapsed_speed?: number | null
          average_flow?: number | null
          average_grade?: number | null
          average_grade_adjusted_pace?: number | null
          average_heart_rate?: number | null
          average_negative_grade?: number | null
          average_positive_grade?: number | null
          average_speed?: number | null
          average_temperature?: number | null
          average_watts?: number | null
          calories?: number | null
          carbon_saved?: number | null
          cloud_cover?: number | null
          commute?: boolean | null
          competition?: boolean | null
          created_at?: string | null
          description?: string | null
          device_name?: string | null
          device_watts?: boolean | null
          dewpoint?: number | null
          dirt_distance?: number | null
          distance?: number | null
          elapsed_time?: number | null
          elevation_gain?: number | null
          elevation_high?: number | null
          elevation_loss?: number | null
          elevation_low?: number | null
          end_latitude?: number | null
          end_longitude?: number | null
          external_id?: string | null
          filename?: string | null
          flagged?: boolean | null
          for_a_cause?: boolean | null
          from_upload?: boolean | null
          gear_id?: string | null
          grade_adjusted_distance?: number | null
          has_heartrate?: boolean | null
          humidity?: number | null
          id: number
          intensity?: number | null
          jump_count?: number | null
          long_run?: boolean | null
          manual?: boolean | null
          map_polyline?: string | null
          map_summary_polyline?: string | null
          max_cadence?: number | null
          max_grade?: number | null
          max_heart_rate?: number | null
          max_speed?: number | null
          max_temperature?: number | null
          max_watts?: number | null
          moving_time?: number | null
          name?: string | null
          newly_explored_dirt_distance?: number | null
          newly_explored_distance?: number | null
          perceived_exertion?: number | null
          pool_length?: number | null
          precipitation_intensity?: number | null
          precipitation_probability?: number | null
          precipitation_type?: string | null
          private?: boolean | null
          raw_data?: Json | null
          relative_effort?: number | null
          resource_state?: number | null
          source?: string | null
          start_latitude?: number | null
          start_longitude?: number | null
          start_time?: string | null
          timer_time?: number | null
          total_cycles?: number | null
          total_grit?: number | null
          total_steps?: number | null
          total_work?: number | null
          trainer?: boolean | null
          training_load?: number | null
          updated_at?: string | null
          uv_index?: number | null
          weather_condition?: string | null
          weather_ozone?: number | null
          weather_pressure?: number | null
          weather_visibility?: number | null
          weighted_average_watts?: number | null
          wind_bearing?: number | null
          wind_gust?: number | null
          wind_speed?: number | null
          with_pet?: boolean | null
        }
        Update: {
          activity_date?: string
          activity_type_id?: number | null
          apparent_temperature?: number | null
          athlete_id?: number
          auth_user_id?: string | null
          average_cadence?: number | null
          average_elapsed_speed?: number | null
          average_flow?: number | null
          average_grade?: number | null
          average_grade_adjusted_pace?: number | null
          average_heart_rate?: number | null
          average_negative_grade?: number | null
          average_positive_grade?: number | null
          average_speed?: number | null
          average_temperature?: number | null
          average_watts?: number | null
          calories?: number | null
          carbon_saved?: number | null
          cloud_cover?: number | null
          commute?: boolean | null
          competition?: boolean | null
          created_at?: string | null
          description?: string | null
          device_name?: string | null
          device_watts?: boolean | null
          dewpoint?: number | null
          dirt_distance?: number | null
          distance?: number | null
          elapsed_time?: number | null
          elevation_gain?: number | null
          elevation_high?: number | null
          elevation_loss?: number | null
          elevation_low?: number | null
          end_latitude?: number | null
          end_longitude?: number | null
          external_id?: string | null
          filename?: string | null
          flagged?: boolean | null
          for_a_cause?: boolean | null
          from_upload?: boolean | null
          gear_id?: string | null
          grade_adjusted_distance?: number | null
          has_heartrate?: boolean | null
          humidity?: number | null
          id?: number
          intensity?: number | null
          jump_count?: number | null
          long_run?: boolean | null
          manual?: boolean | null
          map_polyline?: string | null
          map_summary_polyline?: string | null
          max_cadence?: number | null
          max_grade?: number | null
          max_heart_rate?: number | null
          max_speed?: number | null
          max_temperature?: number | null
          max_watts?: number | null
          moving_time?: number | null
          name?: string | null
          newly_explored_dirt_distance?: number | null
          newly_explored_distance?: number | null
          perceived_exertion?: number | null
          pool_length?: number | null
          precipitation_intensity?: number | null
          precipitation_probability?: number | null
          precipitation_type?: string | null
          private?: boolean | null
          raw_data?: Json | null
          relative_effort?: number | null
          resource_state?: number | null
          source?: string | null
          start_latitude?: number | null
          start_longitude?: number | null
          start_time?: string | null
          timer_time?: number | null
          total_cycles?: number | null
          total_grit?: number | null
          total_steps?: number | null
          total_work?: number | null
          trainer?: boolean | null
          training_load?: number | null
          updated_at?: string | null
          uv_index?: number | null
          weather_condition?: string | null
          weather_ozone?: number | null
          weather_pressure?: number | null
          weather_visibility?: number | null
          weighted_average_watts?: number | null
          wind_bearing?: number | null
          wind_gust?: number | null
          wind_speed?: number | null
          with_pet?: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "activities_activity_type_id_fkey"
            columns: ["activity_type_id"]
            isOneToOne: false
            referencedRelation: "activity_types"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activities_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activities_gear_id_fkey"
            columns: ["gear_id"]
            isOneToOne: false
            referencedRelation: "gear"
            referencedColumns: ["id"]
          },
        ]
      }
      activity_embeddings: {
        Row: {
          activity_id: number | null
          created_at: string | null
          embedding: string | null
          id: string
          summary: string
          updated_at: string | null
        }
        Insert: {
          activity_id?: number | null
          created_at?: string | null
          embedding?: string | null
          id?: string
          summary: string
          updated_at?: string | null
        }
        Update: {
          activity_id?: number | null
          created_at?: string | null
          embedding?: string | null
          id?: string
          summary?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "activity_embeddings_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: true
            referencedRelation: "activities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_embeddings_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: true
            referencedRelation: "activity_summary"
            referencedColumns: ["id"]
          },
        ]
      }
      activity_insights: {
        Row: {
          activity_id: number | null
          confidence_score: number | null
          created_at: string | null
          generated_by: string | null
          id: number
          insight_data: Json
          insight_type: string
        }
        Insert: {
          activity_id?: number | null
          confidence_score?: number | null
          created_at?: string | null
          generated_by?: string | null
          id?: number
          insight_data: Json
          insight_type: string
        }
        Update: {
          activity_id?: number | null
          confidence_score?: number | null
          created_at?: string | null
          generated_by?: string | null
          id?: number
          insight_data?: Json
          insight_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "activity_insights_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: false
            referencedRelation: "activities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "activity_insights_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: false
            referencedRelation: "activity_summary"
            referencedColumns: ["id"]
          },
        ]
      }
      activity_types: {
        Row: {
          category: string | null
          created_at: string | null
          description: string | null
          id: number
          name: string
          updated_at: string | null
        }
        Insert: {
          category?: string | null
          created_at?: string | null
          description?: string | null
          id?: number
          name: string
          updated_at?: string | null
        }
        Update: {
          category?: string | null
          created_at?: string | null
          description?: string | null
          id?: number
          name?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      analytics_events: {
        Row: {
          app_version: string | null
          athlete_id: number | null
          created_at: string
          device_id: string | null
          device_model: string | null
          event_category: string
          event_name: string
          id: string
          latitude: number | null
          longitude: number | null
          os_version: string | null
          properties: Json | null
          session_id: string | null
        }
        Insert: {
          app_version?: string | null
          athlete_id?: number | null
          created_at?: string
          device_id?: string | null
          device_model?: string | null
          event_category: string
          event_name: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          os_version?: string | null
          properties?: Json | null
          session_id?: string | null
        }
        Update: {
          app_version?: string | null
          athlete_id?: number | null
          created_at?: string
          device_id?: string | null
          device_model?: string | null
          event_category?: string
          event_name?: string
          id?: string
          latitude?: number | null
          longitude?: number | null
          os_version?: string | null
          properties?: Json | null
          session_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "analytics_events_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      app_logs: {
        Row: {
          athlete_id: number | null
          created_at: string | null
          device_info: Json | null
          duration_ms: number | null
          environment: string | null
          error_message: string | null
          error_stack: string | null
          function_name: string | null
          id: string
          level: string
          message: string
          metadata: Json | null
          request_body: Json | null
          request_method: string | null
          request_path: string | null
          response_body: Json | null
          response_status: number | null
          session_id: string | null
          source: string
          user_id: string | null
        }
        Insert: {
          athlete_id?: number | null
          created_at?: string | null
          device_info?: Json | null
          duration_ms?: number | null
          environment?: string | null
          error_message?: string | null
          error_stack?: string | null
          function_name?: string | null
          id?: string
          level?: string
          message: string
          metadata?: Json | null
          request_body?: Json | null
          request_method?: string | null
          request_path?: string | null
          response_body?: Json | null
          response_status?: number | null
          session_id?: string | null
          source: string
          user_id?: string | null
        }
        Update: {
          athlete_id?: number | null
          created_at?: string | null
          device_info?: Json | null
          duration_ms?: number | null
          environment?: string | null
          error_message?: string | null
          error_stack?: string | null
          function_name?: string | null
          id?: string
          level?: string
          message?: string
          metadata?: Json | null
          request_body?: Json | null
          request_method?: string | null
          request_path?: string | null
          response_body?: Json | null
          response_status?: number | null
          session_id?: string | null
          source?: string
          user_id?: string | null
        }
        Relationships: []
      }
      athlete_ai_profiles: {
        Row: {
          athlete_id: number | null
          core_memory: Json
          id: string
          last_updated: string | null
          preferences: Json | null
          version: number | null
        }
        Insert: {
          athlete_id?: number | null
          core_memory?: Json
          id?: string
          last_updated?: string | null
          preferences?: Json | null
          version?: number | null
        }
        Update: {
          athlete_id?: number | null
          core_memory?: Json
          id?: string
          last_updated?: string | null
          preferences?: Json | null
          version?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "athlete_ai_profiles_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: true
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      athlete_stats: {
        Row: {
          achievement_count: number | null
          athlete_id: number
          count: number | null
          created_at: string | null
          distance: number | null
          elapsed_time: number | null
          elevation_gain: number | null
          id: number
          moving_time: number | null
          updated_at: string | null
          ytd_distance: number | null
        }
        Insert: {
          achievement_count?: number | null
          athlete_id: number
          count?: number | null
          created_at?: string | null
          distance?: number | null
          elapsed_time?: number | null
          elevation_gain?: number | null
          id?: number
          moving_time?: number | null
          updated_at?: string | null
          ytd_distance?: number | null
        }
        Update: {
          achievement_count?: number | null
          athlete_id?: number
          count?: number | null
          created_at?: string | null
          distance?: number | null
          elapsed_time?: number | null
          elevation_gain?: number | null
          id?: number
          moving_time?: number | null
          updated_at?: string | null
          ytd_distance?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "athlete_stats_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: true
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      athletes: {
        Row: {
          access_token: string | null
          auth_user_id: string | null
          city: string | null
          country: string | null
          created_at: string | null
          description: string | null
          email: string | null
          fcm_token: string | null
          first_name: string | null
          garmin_access_token: string | null
          garmin_connected: boolean | null
          garmin_connected_at: string | null
          garmin_refresh_token: string | null
          garmin_token_expires_at: string | null
          garmin_token_secret: string | null
          health_consent_date: string | null
          health_consent_status: string | null
          id: number
          last_name: string | null
          last_successful_sync_at: string | null
          last_sync_at: string | null
          premium: boolean | null
          profile: string | null
          profile_medium: string | null
          refresh_token: string | null
          sex: string | null
          state: string | null
          strava_connected: boolean | null
          strava_connected_at: string | null
          strava_disconnected_at: string | null
          token_expires_at: string | null
          total_syncs: number | null
          updated_at: string | null
          weight: number | null
        }
        Insert: {
          access_token?: string | null
          auth_user_id?: string | null
          city?: string | null
          country?: string | null
          created_at?: string | null
          description?: string | null
          email?: string | null
          fcm_token?: string | null
          first_name?: string | null
          garmin_access_token?: string | null
          garmin_connected?: boolean | null
          garmin_connected_at?: string | null
          garmin_refresh_token?: string | null
          garmin_token_expires_at?: string | null
          garmin_token_secret?: string | null
          health_consent_date?: string | null
          health_consent_status?: string | null
          id: number
          last_name?: string | null
          last_successful_sync_at?: string | null
          last_sync_at?: string | null
          premium?: boolean | null
          profile?: string | null
          profile_medium?: string | null
          refresh_token?: string | null
          sex?: string | null
          state?: string | null
          strava_connected?: boolean | null
          strava_connected_at?: string | null
          strava_disconnected_at?: string | null
          token_expires_at?: string | null
          total_syncs?: number | null
          updated_at?: string | null
          weight?: number | null
        }
        Update: {
          access_token?: string | null
          auth_user_id?: string | null
          city?: string | null
          country?: string | null
          created_at?: string | null
          description?: string | null
          email?: string | null
          fcm_token?: string | null
          first_name?: string | null
          garmin_access_token?: string | null
          garmin_connected?: boolean | null
          garmin_connected_at?: string | null
          garmin_refresh_token?: string | null
          garmin_token_expires_at?: string | null
          garmin_token_secret?: string | null
          health_consent_date?: string | null
          health_consent_status?: string | null
          id?: number
          last_name?: string | null
          last_successful_sync_at?: string | null
          last_sync_at?: string | null
          premium?: boolean | null
          profile?: string | null
          profile_medium?: string | null
          refresh_token?: string | null
          sex?: string | null
          state?: string | null
          strava_connected?: boolean | null
          strava_connected_at?: string | null
          strava_disconnected_at?: string | null
          token_expires_at?: string | null
          total_syncs?: number | null
          updated_at?: string | null
          weight?: number | null
        }
        Relationships: []
      }
      brands: {
        Row: {
          created_at: string | null
          description: string | null
          id: number
          name: string
          updated_at: string | null
        }
        Insert: {
          created_at?: string | null
          description?: string | null
          id?: number
          name: string
          updated_at?: string | null
        }
        Update: {
          created_at?: string | null
          description?: string | null
          id?: number
          name?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      challenge_participations: {
        Row: {
          athlete_id: number
          challenge_id: number
          completed: boolean | null
          completion_date: string | null
          join_date: string | null
          progress_value: number | null
        }
        Insert: {
          athlete_id: number
          challenge_id: number
          completed?: boolean | null
          completion_date?: string | null
          join_date?: string | null
          progress_value?: number | null
        }
        Update: {
          athlete_id?: number
          challenge_id?: number
          completed?: boolean | null
          completion_date?: string | null
          join_date?: string | null
          progress_value?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "challenge_participations_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "challenge_participations_challenge_id_fkey"
            columns: ["challenge_id"]
            isOneToOne: false
            referencedRelation: "challenges"
            referencedColumns: ["id"]
          },
        ]
      }
      challenges: {
        Row: {
          challenge_type: string | null
          created_at: string | null
          description: string | null
          end_date: string | null
          id: number
          name: string
          start_date: string | null
          target_unit: string | null
          target_value: number | null
        }
        Insert: {
          challenge_type?: string | null
          created_at?: string | null
          description?: string | null
          end_date?: string | null
          id?: number
          name: string
          start_date?: string | null
          target_unit?: string | null
          target_value?: number | null
        }
        Update: {
          challenge_type?: string | null
          created_at?: string | null
          description?: string | null
          end_date?: string | null
          id?: number
          name?: string
          start_date?: string | null
          target_unit?: string | null
          target_value?: number | null
        }
        Relationships: []
      }
      chat_conversations: {
        Row: {
          athlete_id: number | null
          context_used: Json | null
          conversation_id: string | null
          conversation_summary: string | null
          id: string
          message: string
          role: string | null
          timestamp: string | null
        }
        Insert: {
          athlete_id?: number | null
          context_used?: Json | null
          conversation_id?: string | null
          conversation_summary?: string | null
          id?: string
          message: string
          role?: string | null
          timestamp?: string | null
        }
        Update: {
          athlete_id?: number | null
          context_used?: Json | null
          conversation_id?: string | null
          conversation_summary?: string | null
          id?: string
          message?: string
          role?: string | null
          timestamp?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "chat_conversations_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      clubs: {
        Row: {
          city: string | null
          club_picture: string | null
          club_type: string | null
          country: string | null
          cover_photo: string | null
          created_at: string | null
          description: string | null
          id: number
          member_count: number | null
          name: string
          sport: string | null
          state: string | null
          updated_at: string | null
          website: string | null
        }
        Insert: {
          city?: string | null
          club_picture?: string | null
          club_type?: string | null
          country?: string | null
          cover_photo?: string | null
          created_at?: string | null
          description?: string | null
          id?: number
          member_count?: number | null
          name: string
          sport?: string | null
          state?: string | null
          updated_at?: string | null
          website?: string | null
        }
        Update: {
          city?: string | null
          club_picture?: string | null
          club_type?: string | null
          country?: string | null
          cover_photo?: string | null
          created_at?: string | null
          description?: string | null
          id?: number
          member_count?: number | null
          name?: string
          sport?: string | null
          state?: string | null
          updated_at?: string | null
          website?: string | null
        }
        Relationships: []
      }
      comments: {
        Row: {
          activity_id: number | null
          athlete_id: number | null
          comment_date: string | null
          content: string
          id: number
        }
        Insert: {
          activity_id?: number | null
          athlete_id?: number | null
          comment_date?: string | null
          content: string
          id?: number
        }
        Update: {
          activity_id?: number | null
          athlete_id?: number | null
          comment_date?: string | null
          content?: string
          id?: number
        }
        Relationships: [
          {
            foreignKeyName: "comments_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: false
            referencedRelation: "activities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: false
            referencedRelation: "activity_summary"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "comments_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      connected_apps: {
        Row: {
          app_name: string | null
          athlete_id: number | null
          connected_at: string | null
          enabled: boolean | null
          id: number
          last_used: string | null
        }
        Insert: {
          app_name?: string | null
          athlete_id?: number | null
          connected_at?: string | null
          enabled?: boolean | null
          id?: number
          last_used?: string | null
        }
        Update: {
          app_name?: string | null
          athlete_id?: number | null
          connected_at?: string | null
          enabled?: boolean | null
          id?: number
          last_used?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "connected_apps_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      conversations: {
        Row: {
          context: Json | null
          created_at: string
          id: string
          messages: Json
          updated_at: string
          user_id: string
        }
        Insert: {
          context?: Json | null
          created_at?: string
          id?: string
          messages?: Json
          updated_at?: string
          user_id: string
        }
        Update: {
          context?: Json | null
          created_at?: string
          id?: string
          messages?: Json
          updated_at?: string
          user_id?: string
        }
        Relationships: []
      }
      daily_commitments: {
        Row: {
          activity_type: string
          athlete_id: number
          commitment_date: string
          commitment_level: string | null
          created_at: string
          fulfilled_at: string | null
          id: number
          is_fulfilled: boolean
          micro_commitment_type: string | null
          progression_step: number | null
          updated_at: string
        }
        Insert: {
          activity_type: string
          athlete_id: number
          commitment_date: string
          commitment_level?: string | null
          created_at?: string
          fulfilled_at?: string | null
          id?: number
          is_fulfilled?: boolean
          micro_commitment_type?: string | null
          progression_step?: number | null
          updated_at?: string
        }
        Update: {
          activity_type?: string
          athlete_id?: number
          commitment_date?: string
          commitment_level?: string | null
          created_at?: string
          fulfilled_at?: string | null
          id?: number
          is_fulfilled?: boolean
          micro_commitment_type?: string | null
          progression_step?: number | null
          updated_at?: string
        }
        Relationships: [
          {
            foreignKeyName: "daily_commitments_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      feature_flags: {
        Row: {
          description: string | null
          enabled: boolean | null
          id: string
          updated_at: string | null
        }
        Insert: {
          description?: string | null
          enabled?: boolean | null
          id: string
          updated_at?: string | null
        }
        Update: {
          description?: string | null
          enabled?: boolean | null
          id?: string
          updated_at?: string | null
        }
        Relationships: []
      }
      follows: {
        Row: {
          created_at: string | null
          follow_status: string | null
          follower_id: number
          following_id: number
          is_favorite: boolean | null
        }
        Insert: {
          created_at?: string | null
          follow_status?: string | null
          follower_id: number
          following_id: number
          is_favorite?: boolean | null
        }
        Update: {
          created_at?: string | null
          follow_status?: string | null
          follower_id?: number
          following_id?: number
          is_favorite?: boolean | null
        }
        Relationships: [
          {
            foreignKeyName: "follows_follower_id_fkey"
            columns: ["follower_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "follows_following_id_fkey"
            columns: ["following_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      garmin_oauth_tokens: {
        Row: {
          auth_user_id: string | null
          created_at: string | null
          expires_at: string
          id: string
          oauth_token: string
          token_secret: string
        }
        Insert: {
          auth_user_id?: string | null
          created_at?: string | null
          expires_at: string
          id?: string
          oauth_token: string
          token_secret: string
        }
        Update: {
          auth_user_id?: string | null
          created_at?: string | null
          expires_at?: string
          id?: string
          oauth_token?: string
          token_secret?: string
        }
        Relationships: []
      }
      gear: {
        Row: {
          athlete_id: number
          brand_id: number | null
          created_at: string | null
          gear_type: string
          id: string
          is_primary: boolean | null
          model_id: number | null
          name: string | null
          retired: boolean | null
          total_distance: number | null
          updated_at: string | null
        }
        Insert: {
          athlete_id: number
          brand_id?: number | null
          created_at?: string | null
          gear_type: string
          id: string
          is_primary?: boolean | null
          model_id?: number | null
          name?: string | null
          retired?: boolean | null
          total_distance?: number | null
          updated_at?: string | null
        }
        Update: {
          athlete_id?: number
          brand_id?: number | null
          created_at?: string | null
          gear_type?: string
          id?: string
          is_primary?: boolean | null
          model_id?: number | null
          name?: string | null
          retired?: boolean | null
          total_distance?: number | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "gear_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "gear_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "gear_model_id_fkey"
            columns: ["model_id"]
            isOneToOne: false
            referencedRelation: "models"
            referencedColumns: ["id"]
          },
        ]
      }
      goals: {
        Row: {
          activity_type: string | null
          athlete_id: number | null
          completed: boolean | null
          created_at: string | null
          current_value: number | null
          end_date: string | null
          goal_type: string | null
          id: number
          interval_time: number | null
          segment_id: number | null
          start_date: string | null
          target_value: number | null
          time_period: string | null
        }
        Insert: {
          activity_type?: string | null
          athlete_id?: number | null
          completed?: boolean | null
          created_at?: string | null
          current_value?: number | null
          end_date?: string | null
          goal_type?: string | null
          id?: number
          interval_time?: number | null
          segment_id?: number | null
          start_date?: string | null
          target_value?: number | null
          time_period?: string | null
        }
        Update: {
          activity_type?: string | null
          athlete_id?: number | null
          completed?: boolean | null
          created_at?: string | null
          current_value?: number | null
          end_date?: string | null
          goal_type?: string | null
          id?: number
          interval_time?: number | null
          segment_id?: number | null
          start_date?: string | null
          target_value?: number | null
          time_period?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "goals_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "goals_segment_id_fkey"
            columns: ["segment_id"]
            isOneToOne: false
            referencedRelation: "segments"
            referencedColumns: ["id"]
          },
        ]
      }
      logins: {
        Row: {
          athlete_id: number | null
          id: number
          ip_address: unknown
          location: string | null
          login_datetime: string | null
          login_source: string | null
          user_agent: string | null
        }
        Insert: {
          athlete_id?: number | null
          id?: number
          ip_address?: unknown
          location?: string | null
          login_datetime?: string | null
          login_source?: string | null
          user_agent?: string | null
        }
        Update: {
          athlete_id?: number | null
          id?: number
          ip_address?: unknown
          location?: string | null
          login_datetime?: string | null
          login_source?: string | null
          user_agent?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "logins_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      media: {
        Row: {
          activity_id: number | null
          athlete_id: number | null
          caption: string | null
          created_at: string | null
          file_size: number | null
          filename: string | null
          id: number
          media_type: string | null
        }
        Insert: {
          activity_id?: number | null
          athlete_id?: number | null
          caption?: string | null
          created_at?: string | null
          file_size?: number | null
          filename?: string | null
          id?: number
          media_type?: string | null
        }
        Update: {
          activity_id?: number | null
          athlete_id?: number | null
          caption?: string | null
          created_at?: string | null
          file_size?: number | null
          filename?: string | null
          id?: number
          media_type?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "media_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: false
            referencedRelation: "activities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "media_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: false
            referencedRelation: "activity_summary"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "media_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      memberships: {
        Row: {
          athlete_id: number
          club_id: number
          join_date: string | null
          role: string | null
          status: string | null
        }
        Insert: {
          athlete_id: number
          club_id: number
          join_date?: string | null
          role?: string | null
          status?: string | null
        }
        Update: {
          athlete_id?: number
          club_id?: number
          join_date?: string | null
          role?: string | null
          status?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "memberships_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "memberships_club_id_fkey"
            columns: ["club_id"]
            isOneToOne: false
            referencedRelation: "clubs"
            referencedColumns: ["id"]
          },
        ]
      }
      models: {
        Row: {
          brand_id: number | null
          category: string | null
          created_at: string | null
          description: string | null
          id: number
          name: string
          updated_at: string | null
        }
        Insert: {
          brand_id?: number | null
          category?: string | null
          created_at?: string | null
          description?: string | null
          id?: number
          name: string
          updated_at?: string | null
        }
        Update: {
          brand_id?: number | null
          category?: string | null
          created_at?: string | null
          description?: string | null
          id?: number
          name?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "models_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
        ]
      }
      oauth_tokens: {
        Row: {
          access_token: string
          athlete_id: number
          created_at: string | null
          expires_at: string
          id: string
          refresh_token: string
          scope: string | null
          token_type: string | null
          updated_at: string | null
        }
        Insert: {
          access_token: string
          athlete_id: number
          created_at?: string | null
          expires_at: string
          id?: string
          refresh_token: string
          scope?: string | null
          token_type?: string | null
          updated_at?: string | null
        }
        Update: {
          access_token?: string
          athlete_id?: number
          created_at?: string | null
          expires_at?: string
          id?: string
          refresh_token?: string
          scope?: string | null
          token_type?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "oauth_tokens_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: true
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      reactions: {
        Row: {
          athlete_id: number | null
          id: number
          parent_id: number
          parent_type: string
          reaction_date: string | null
          reaction_type: string
        }
        Insert: {
          athlete_id?: number | null
          id?: number
          parent_id: number
          parent_type: string
          reaction_date?: string | null
          reaction_type: string
        }
        Update: {
          athlete_id?: number | null
          id?: number
          parent_id?: number
          parent_type?: string
          reaction_date?: string | null
          reaction_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "reactions_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      research_articles: {
        Row: {
          author: string | null
          category: string
          content: string | null
          created_at: string | null
          fetched_at: string | null
          id: string
          image_url: string | null
          is_active: boolean | null
          is_local_event: boolean | null
          location_city: string | null
          location_country: string | null
          location_latitude: number | null
          location_longitude: number | null
          location_state: string | null
          published_at: string | null
          relevance_score: number | null
          source: string
          summary: string | null
          tags: string[] | null
          title: string
          updated_at: string | null
          url: string
        }
        Insert: {
          author?: string | null
          category?: string
          content?: string | null
          created_at?: string | null
          fetched_at?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean | null
          is_local_event?: boolean | null
          location_city?: string | null
          location_country?: string | null
          location_latitude?: number | null
          location_longitude?: number | null
          location_state?: string | null
          published_at?: string | null
          relevance_score?: number | null
          source: string
          summary?: string | null
          tags?: string[] | null
          title: string
          updated_at?: string | null
          url: string
        }
        Update: {
          author?: string | null
          category?: string
          content?: string | null
          created_at?: string | null
          fetched_at?: string | null
          id?: string
          image_url?: string | null
          is_active?: boolean | null
          is_local_event?: boolean | null
          location_city?: string | null
          location_country?: string | null
          location_latitude?: number | null
          location_longitude?: number | null
          location_state?: string | null
          published_at?: string | null
          relevance_score?: number | null
          source?: string
          summary?: string | null
          tags?: string[] | null
          title?: string
          updated_at?: string | null
          url?: string
        }
        Relationships: []
      }
      rest_days: {
        Row: {
          athlete_id: number
          created_at: string | null
          date: string
          id: string
          is_planned: boolean | null
          notes: string | null
          reason: string | null
          recovery_benefit: number | null
          updated_at: string | null
        }
        Insert: {
          athlete_id: number
          created_at?: string | null
          date: string
          id?: string
          is_planned?: boolean | null
          notes?: string | null
          reason?: string | null
          recovery_benefit?: number | null
          updated_at?: string | null
        }
        Update: {
          athlete_id?: number
          created_at?: string | null
          date?: string
          id?: string
          is_planned?: boolean | null
          notes?: string | null
          reason?: string | null
          recovery_benefit?: number | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "rest_days_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      routes: {
        Row: {
          athlete_id: number
          created_at: string | null
          description: string | null
          distance: number | null
          elevation_gain: number | null
          filename: string | null
          id: number
          name: string | null
          updated_at: string | null
        }
        Insert: {
          athlete_id: number
          created_at?: string | null
          description?: string | null
          distance?: number | null
          elevation_gain?: number | null
          filename?: string | null
          id?: number
          name?: string | null
          updated_at?: string | null
        }
        Update: {
          athlete_id?: number
          created_at?: string | null
          description?: string | null
          distance?: number | null
          elevation_gain?: number | null
          filename?: string | null
          id?: number
          name?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "routes_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      running_goals: {
        Row: {
          athlete_id: number
          completed_at: string | null
          created_at: string | null
          current_progress: number | null
          deadline: string
          goal_type: string
          id: number
          is_active: boolean | null
          is_completed: boolean | null
          target_value: number
          title: string
          updated_at: string | null
        }
        Insert: {
          athlete_id: number
          completed_at?: string | null
          created_at?: string | null
          current_progress?: number | null
          deadline: string
          goal_type: string
          id?: number
          is_active?: boolean | null
          is_completed?: boolean | null
          target_value: number
          title: string
          updated_at?: string | null
        }
        Update: {
          athlete_id?: number
          completed_at?: string | null
          created_at?: string | null
          current_progress?: number | null
          deadline?: string
          goal_type?: string
          id?: number
          is_active?: boolean | null
          is_completed?: boolean | null
          target_value?: number
          title?: string
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "fk_running_goals_athlete_id"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      segments: {
        Row: {
          activity_id: number | null
          average_grade: number | null
          city: string | null
          climb_category: number | null
          country: string | null
          created_at: string | null
          distance: number | null
          elevation_high: number | null
          elevation_low: number | null
          end_latitude: number | null
          end_longitude: number | null
          hazardous: boolean | null
          id: number
          maximum_grade: number | null
          name: string | null
          starred: boolean | null
          start_latitude: number | null
          start_longitude: number | null
          state: string | null
        }
        Insert: {
          activity_id?: number | null
          average_grade?: number | null
          city?: string | null
          climb_category?: number | null
          country?: string | null
          created_at?: string | null
          distance?: number | null
          elevation_high?: number | null
          elevation_low?: number | null
          end_latitude?: number | null
          end_longitude?: number | null
          hazardous?: boolean | null
          id?: number
          maximum_grade?: number | null
          name?: string | null
          starred?: boolean | null
          start_latitude?: number | null
          start_longitude?: number | null
          state?: string | null
        }
        Update: {
          activity_id?: number | null
          average_grade?: number | null
          city?: string | null
          climb_category?: number | null
          country?: string | null
          created_at?: string | null
          distance?: number | null
          elevation_high?: number | null
          elevation_low?: number | null
          end_latitude?: number | null
          end_longitude?: number | null
          hazardous?: boolean | null
          id?: number
          maximum_grade?: number | null
          name?: string | null
          starred?: boolean | null
          start_latitude?: number | null
          start_longitude?: number | null
          state?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "segments_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: false
            referencedRelation: "activities"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "segments_activity_id_fkey"
            columns: ["activity_id"]
            isOneToOne: false
            referencedRelation: "activity_summary"
            referencedColumns: ["id"]
          },
        ]
      }
      starred_routes: {
        Row: {
          athlete_id: number
          route_id: number
          starred_at: string | null
        }
        Insert: {
          athlete_id: number
          route_id: number
          starred_at?: string | null
        }
        Update: {
          athlete_id?: number
          route_id?: number
          starred_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "starred_routes_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "starred_routes_route_id_fkey"
            columns: ["route_id"]
            isOneToOne: false
            referencedRelation: "routes"
            referencedColumns: ["id"]
          },
        ]
      }
      starred_segments: {
        Row: {
          athlete_id: number
          segment_id: number
          starred_at: string | null
        }
        Insert: {
          athlete_id: number
          segment_id: number
          starred_at?: string | null
        }
        Update: {
          athlete_id?: number
          segment_id?: number
          starred_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "starred_segments_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "starred_segments_segment_id_fkey"
            columns: ["segment_id"]
            isOneToOne: false
            referencedRelation: "segments"
            referencedColumns: ["id"]
          },
        ]
      }
      sync_jobs: {
        Row: {
          after_date: string | null
          athlete_id: number
          before_date: string | null
          completed_at: string | null
          created_at: string | null
          error_message: string | null
          error_stack: string | null
          failed_activities: number | null
          id: string
          metadata: Json | null
          processed_activities: number | null
          started_at: string | null
          status: string
          sync_type: string | null
          total_activities: number | null
        }
        Insert: {
          after_date?: string | null
          athlete_id: number
          before_date?: string | null
          completed_at?: string | null
          created_at?: string | null
          error_message?: string | null
          error_stack?: string | null
          failed_activities?: number | null
          id?: string
          metadata?: Json | null
          processed_activities?: number | null
          started_at?: string | null
          status?: string
          sync_type?: string | null
          total_activities?: number | null
        }
        Update: {
          after_date?: string | null
          athlete_id?: number
          before_date?: string | null
          completed_at?: string | null
          created_at?: string | null
          error_message?: string | null
          error_stack?: string | null
          failed_activities?: number | null
          id?: string
          metadata?: Json | null
          processed_activities?: number | null
          started_at?: string | null
          status?: string
          sync_type?: string | null
          total_activities?: number | null
        }
        Relationships: [
          {
            foreignKeyName: "sync_jobs_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      training_journal: {
        Row: {
          athlete_id: number
          generation_model: string | null
          generation_timestamp: string | null
          goal_progress: Json | null
          id: string
          insights: Json | null
          narrative: string
          updated_at: string | null
          week_end_date: string
          week_start_date: string
          week_stats: Json | null
        }
        Insert: {
          athlete_id: number
          generation_model?: string | null
          generation_timestamp?: string | null
          goal_progress?: Json | null
          id?: string
          insights?: Json | null
          narrative: string
          updated_at?: string | null
          week_end_date: string
          week_start_date: string
          week_stats?: Json | null
        }
        Update: {
          athlete_id?: number
          generation_model?: string | null
          generation_timestamp?: string | null
          goal_progress?: Json | null
          id?: string
          insights?: Json | null
          narrative?: string
          updated_at?: string | null
          week_end_date?: string
          week_start_date?: string
          week_stats?: Json | null
        }
        Relationships: []
      }
      training_zones: {
        Row: {
          athlete_id: number | null
          created_at: string | null
          id: number
          max_value: number
          min_value: number
          zone_number: number
          zone_type: string
        }
        Insert: {
          athlete_id?: number | null
          created_at?: string | null
          id?: number
          max_value: number
          min_value: number
          zone_number: number
          zone_type: string
        }
        Update: {
          athlete_id?: number | null
          created_at?: string | null
          id?: number
          max_value?: number
          min_value?: number
          zone_number?: number
          zone_type?: string
        }
        Relationships: [
          {
            foreignKeyName: "training_zones_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      user_preferences: {
        Row: {
          athlete_id: number | null
          auto_pause_enabled: boolean | null
          created_at: string | null
          dark_mode_enabled: boolean | null
          id: number
          notifications_enabled: boolean | null
          privacy_level: string | null
          units_system: string | null
          updated_at: string | null
        }
        Insert: {
          athlete_id?: number | null
          auto_pause_enabled?: boolean | null
          created_at?: string | null
          dark_mode_enabled?: boolean | null
          id?: number
          notifications_enabled?: boolean | null
          privacy_level?: string | null
          units_system?: string | null
          updated_at?: string | null
        }
        Update: {
          athlete_id?: number | null
          auto_pause_enabled?: boolean | null
          created_at?: string | null
          dark_mode_enabled?: boolean | null
          id?: number
          notifications_enabled?: boolean | null
          privacy_level?: string | null
          units_system?: string | null
          updated_at?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "user_preferences_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: true
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      weekly_training_plans: {
        Row: {
          athlete_id: number
          created_at: string | null
          focus_area: string | null
          generated_at: string | null
          goal_id: number | null
          id: string
          is_regenerated: boolean | null
          notes: string | null
          regeneration_reason: string | null
          total_mileage: number | null
          updated_at: string | null
          week_end_date: string
          week_number: number | null
          week_start_date: string
          workouts: Json
        }
        Insert: {
          athlete_id: number
          created_at?: string | null
          focus_area?: string | null
          generated_at?: string | null
          goal_id?: number | null
          id?: string
          is_regenerated?: boolean | null
          notes?: string | null
          regeneration_reason?: string | null
          total_mileage?: number | null
          updated_at?: string | null
          week_end_date: string
          week_number?: number | null
          week_start_date: string
          workouts?: Json
        }
        Update: {
          athlete_id?: number
          created_at?: string | null
          focus_area?: string | null
          generated_at?: string | null
          goal_id?: number | null
          id?: string
          is_regenerated?: boolean | null
          notes?: string | null
          regeneration_reason?: string | null
          total_mileage?: number | null
          updated_at?: string | null
          week_end_date?: string
          week_number?: number | null
          week_start_date?: string
          workouts?: Json
        }
        Relationships: [
          {
            foreignKeyName: "weekly_training_plans_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "weekly_training_plans_goal_id_fkey"
            columns: ["goal_id"]
            isOneToOne: false
            referencedRelation: "running_goals"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Views: {
      activity_summary: {
        Row: {
          activity_date: string | null
          activity_type: string | null
          average_heart_rate: number | null
          average_speed: number | null
          average_watts: number | null
          calories: number | null
          distance: number | null
          elapsed_time: number | null
          elevation_gain: number | null
          gear_name: string | null
          id: number | null
          name: string | null
        }
        Relationships: []
      }
      analytics_activity_funnel: {
        Row: {
          date: string | null
          discarded: number | null
          paused: number | null
          resumed: number | null
          saved: number | null
          started: number | null
          stopped: number | null
        }
        Relationships: []
      }
      analytics_activity_hours: {
        Row: {
          activity_count: number | null
          day_of_week: number | null
          hour_of_day: number | null
        }
        Relationships: []
      }
      analytics_audio_coaching: {
        Row: {
          avg_elapsed_time: number | null
          count: number | null
          date: string | null
          event_name: string | null
          unique_users: number | null
        }
        Relationships: []
      }
      analytics_daily_summary: {
        Row: {
          date: string | null
          event_category: string | null
          event_count: number | null
          event_name: string | null
          unique_sessions: number | null
          unique_users: number | null
        }
        Relationships: []
      }
      analytics_user_engagement: {
        Row: {
          active_days: number | null
          activities_completed: number | null
          activity_events: number | null
          athlete_id: number | null
          first_seen: string | null
          last_seen: string | null
          total_events: number | null
          total_sessions: number | null
        }
        Relationships: [
          {
            foreignKeyName: "analytics_events_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      conversation_summaries: {
        Row: {
          athlete_id: number | null
          conversation_id: string | null
          last_message_at: string | null
          last_user_message: string | null
          message_count: number | null
          started_at: string | null
        }
        Relationships: [
          {
            foreignKeyName: "chat_conversations_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      monthly_activity_stats: {
        Row: {
          activity_count: number | null
          activity_type: string | null
          athlete_id: number | null
          avg_distance: number | null
          month: number | null
          total_distance: number | null
          total_elevation: number | null
          total_time: number | null
          year: number | null
        }
        Relationships: [
          {
            foreignKeyName: "activities_athlete_id_fkey"
            columns: ["athlete_id"]
            isOneToOne: false
            referencedRelation: "athletes"
            referencedColumns: ["id"]
          },
        ]
      }
      recent_journal_entries: {
        Row: {
          athlete_id: number | null
          generation_timestamp: string | null
          insights: Json | null
          narrative: string | null
          week_end_date: string | null
          week_start_date: string | null
          week_stats: Json | null
        }
        Insert: {
          athlete_id?: number | null
          generation_timestamp?: string | null
          insights?: Json | null
          narrative?: string | null
          week_end_date?: string | null
          week_start_date?: string | null
          week_stats?: Json | null
        }
        Update: {
          athlete_id?: number | null
          generation_timestamp?: string | null
          insights?: Json | null
          narrative?: string | null
          week_end_date?: string | null
          week_start_date?: string | null
          week_stats?: Json | null
        }
        Relationships: []
      }
    }
    Functions: {
      analyze_all_tables: { Args: never; Returns: undefined }
      calculate_streak: { Args: { p_athlete_id: number }; Returns: number }
      cleanup_old_research_articles: { Args: never; Returns: number }
      detect_rest_days: {
        Args: { p_athlete_id: number; p_lookback_days?: number }
        Returns: number
      }
      get_commitment_stats: {
        Args: { p_athlete_id: number; p_days?: number }
        Returns: {
          current_streak: number
          fulfilled_commitments: number
          fulfillment_rate: number
          total_commitments: number
        }[]
      }
      get_consecutive_rest_days: {
        Args: { p_athlete_id: number; p_end_date?: string }
        Returns: number
      }
      get_current_week_plan: {
        Args: { p_athlete_id: number }
        Returns: {
          athlete_id: number
          created_at: string | null
          focus_area: string | null
          generated_at: string | null
          goal_id: number | null
          id: string
          is_regenerated: boolean | null
          notes: string | null
          regeneration_reason: string | null
          total_mileage: number | null
          updated_at: string | null
          week_end_date: string
          week_number: number | null
          week_start_date: string
          workouts: Json
        }
        SetofOptions: {
          from: "*"
          to: "weekly_training_plans"
          isOneToOne: true
          isSetofReturn: false
        }
      }
      get_index_usage: {
        Args: never
        Returns: {
          idx_scan: number
          idx_tup_fetch: number
          idx_tup_read: number
          indexname: string
          schemaname: string
          tablename: string
        }[]
      }
      get_lifetime_running_stats: {
        Args: { p_athlete_id: number }
        Returns: Json
      }
      get_monthly_commitment_summary: {
        Args: { p_athlete_id: number }
        Returns: {
          fulfilled_commitments: number
          fulfillment_rate: number
          month_start: string
          most_common_type: string
          total_commitments: number
        }[]
      }
      get_monthly_running_stats: {
        Args: { p_athlete_id: number; p_month?: number; p_year?: number }
        Returns: {
          average_pace_per_mile_seconds: number
          month: number
          total_distance_meters: number
          total_distance_miles: number
          total_elevation_gain_meters: number
          total_moving_time_seconds: number
          total_runs: number
          year: number
        }[]
      }
      get_rest_day_history: {
        Args: { p_athlete_id: number; p_days?: number }
        Returns: {
          date: string
          id: string
          is_planned: boolean
          notes: string
          reason: string
          recovery_benefit: number
        }[]
      }
      get_rest_days_count: {
        Args: { p_athlete_id: number; p_end_date: string; p_start_date: string }
        Returns: number
      }
      get_weekly_commitment_summary: {
        Args: { p_athlete_id: number }
        Returns: {
          fulfilled_commitments: number
          fulfillment_rate: number
          total_commitments: number
          week_start: string
        }[]
      }
      get_yearly_running_stats: {
        Args: { p_athlete_id: number; p_year?: number }
        Returns: {
          average_pace_per_mile_seconds: number
          fastest_pace_per_mile_seconds: number
          longest_run_meters: number
          total_distance_meters: number
          total_distance_miles: number
          total_elapsed_time_seconds: number
          total_elevation_gain_meters: number
          total_moving_time_seconds: number
          total_runs: number
          year: number
        }[]
      }
      match_activities: {
        Args: {
          match_count?: number
          match_threshold?: number
          query_embedding: string
        }
        Returns: {
          activity_date: string
          activity_id: number
          athlete_id: number
          distance: number
          moving_time: number
          similarity: number
          summary: string
        }[]
      }
    }
    Enums: {
      [_ in never]: never
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  graphql_public: {
    Enums: {},
  },
  public: {
    Enums: {},
  },
} as const
