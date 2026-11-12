#
# This file is part of Edgehog.
#
# Copyright 2026 SECO Mind Srl
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#
# SPDX-License-Identifier: Apache-2.0
#

defmodule EdgehogWeb.ChannelsLive.CampaignStripComponent do
  @moduledoc """
  Stateless function component and helpers for selecting, formatting, and
  rendering a channel's active or most recent rollout campaign progress strip.
  """
  use EdgehogWeb, :html

  @active_campaign_statuses [:idle, :scheduled, :in_progress, :pausing, :paused]
  @running_campaign_statuses [:idle, :in_progress, :pausing, :paused]

  @campaign_loads [
    :total_target_count,
    :idle_target_count,
    :in_progress_target_count,
    :failed_target_count,
    :successful_target_count
  ]

  @doc """
  Returns the list of campaign target count aggregates loaded for channel views.
  """
  def campaign_loads, do: @campaign_loads

  @doc """
  Returns true when a campaign status represents an active or scheduled rollout.
  """
  def active_campaign_status?(status), do: status in @active_campaign_statuses

  @doc """
  Returns true when a campaign status represents an actively executing or paused
  campaign whose channel target groups must not be reassigned.
  """
  def running_campaign_status?(status), do: status in @running_campaign_statuses

  @doc """
  Selects the featured campaign for a channel, prioritizing any active or
  scheduled rollout before falling back to the most recently created campaign.
  """
  def pick_featured_campaign([]), do: nil

  def pick_featured_campaign(campaigns) when is_list(campaigns) do
    sorted =
      Enum.sort_by(
        campaigns,
        fn campaign -> {campaign.inserted_at, campaign.id} end,
        {:desc, :desc}
      )

    Enum.find(sorted, &active_campaign_status?(&1.status)) || List.first(sorted)
  end

  attr :campaign, :any, default: nil

  def campaign_strip(%{campaign: nil} = assigns) do
    ~H"""
    <div data-role="channel-campaign-strip" class="border-t border-base-200 pt-3.5">
      <div
        data-role="no-campaigns"
        class="flex items-center justify-between text-xs text-base-content/60"
      >
        <span>No campaigns executed yet</span>
        <span class="font-mono text-[11px] uppercase tracking-wider text-base-content/60">Idle</span>
      </div>
    </div>
    """
  end

  def campaign_strip(%{campaign: campaign} = assigns) do
    total_targets = campaign.total_target_count || 0
    successful = campaign.successful_target_count || 0
    in_progress = campaign.in_progress_target_count || 0
    failed = campaign.failed_target_count || 0
    completed = successful + failed

    progress_pct =
      if total_targets > 0 do
        round(completed / total_targets * 100)
      else
        0
      end

    assigns =
      assigns
      |> assign(:mechanism_label, format_mechanism(campaign.campaign_mechanism))
      |> assign(:status_badge, campaign_status_badge(campaign))
      |> assign(:total_targets, total_targets)
      |> assign(:successful, successful)
      |> assign(:in_progress, in_progress)
      |> assign(:failed, failed)
      |> assign(:progress_pct, progress_pct)

    ~H"""
    <div data-role="channel-campaign-strip" class="border-t border-base-200 pt-3.5">
      <div class="flex flex-col gap-2">
        <div class="flex items-center justify-between gap-2">
          <div class="min-w-0 flex items-center gap-1.5">
            <.icon name="hero-rocket-launch" class="size-3.5 shrink-0 text-base-content/55" />
            <span
              data-role="latest-campaign-name"
              class="text-xs font-semibold text-base-content truncate"
            >
              {@campaign.name}
            </span>
            <span class="text-[11px] text-base-content/50 truncate">
              · {@mechanism_label}
            </span>
          </div>

          <span
            data-role="latest-campaign-status"
            class={["badge badge-xs font-medium shrink-0", @status_badge.class]}
          >
            {@status_badge.label}
          </span>
        </div>

        <div class="flex items-center justify-between text-[11px] tabular-nums text-base-content/60">
          <span data-role="latest-campaign-targets">
            {@successful} succeeded · {@in_progress} in progress · {@failed} failed
          </span>
          <span class="font-medium">
            {@successful + @failed}/{@total_targets} ({@progress_pct}%)
          </span>
        </div>

        <progress
          class={["progress w-full h-1.5", @status_badge.progress_class]}
          value={@progress_pct}
          max="100"
        />
      </div>
    </div>
    """
  end

  defp format_mechanism(%Ash.Union{type: type}), do: format_mechanism_type(type)
  defp format_mechanism(%{type: type}), do: format_mechanism_type(type)
  defp format_mechanism(_), do: "Rollout"

  defp format_mechanism_type(:firmware_upgrade), do: "Firmware Upgrade"
  defp format_mechanism_type(:deployment_deploy), do: "Container Deploy"
  defp format_mechanism_type(:deployment_start), do: "Container Start"
  defp format_mechanism_type(:deployment_stop), do: "Container Stop"
  defp format_mechanism_type(:deployment_delete), do: "Container Delete"
  defp format_mechanism_type(:deployment_upgrade), do: "Container Upgrade"
  defp format_mechanism_type(:file_download), do: "File Download"
  defp format_mechanism_type(_), do: "Rollout"

  defp campaign_status_badge(%{status: :in_progress}) do
    %{label: "In Progress", class: "badge-soft badge-primary", progress_class: "progress-primary"}
  end

  defp campaign_status_badge(%{status: :scheduled}) do
    %{label: "Scheduled", class: "badge-soft badge-info", progress_class: "progress-info"}
  end

  defp campaign_status_badge(%{status: :idle}) do
    %{label: "Starting", class: "badge-soft badge-info", progress_class: "progress-info"}
  end

  defp campaign_status_badge(%{status: status}) when status in [:paused, :pausing] do
    %{label: "Paused", class: "badge-soft badge-warning", progress_class: "progress-warning"}
  end

  defp campaign_status_badge(%{status: :finished, outcome: :failure}) do
    %{label: "Failed", class: "badge-soft badge-error", progress_class: "progress-error"}
  end

  defp campaign_status_badge(%{status: :finished}) do
    %{label: "Succeeded", class: "badge-soft badge-success", progress_class: "progress-success"}
  end

  defp campaign_status_badge(_campaign) do
    %{label: "Idle", class: "badge-ghost", progress_class: "progress-primary"}
  end
end
