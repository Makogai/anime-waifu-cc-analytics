<?php

declare(strict_types=1);

final class DiscordNotifier
{
    public function __construct(private string $webhookUrl) {}

    public function isConfigured(): bool
    {
        return $this->webhookUrl !== '' && str_contains($this->webhookUrl, 'discord');
    }

    public function sendSummary(array $purchasesByPlayer, int $intervalMinutes, string $sinceLabel): bool
    {
        if (!$this->isConfigured() || $purchasesByPlayer === []) {
            return false;
        }

        $total = 0;
        $lines = [];
        foreach ($purchasesByPlayer as $player => $items) {
            $lines[] = "**{$player}** — " . count($items) . ' buy(s)';
            foreach ($items as $item) {
                $lines[] = '• ' . $item;
            }
            $total += count($items);
        }

        $description = implode("\n", array_slice($lines, 0, 40));
        if (count($lines) > 40) {
            $description .= "\n… _and more_";
        }

        $payload = [
            'embeds' => [[
                'title' => '🛒 Pack purchase summary',
                'description' => $description !== '' ? $description : '_No purchases in this window._',
                'color' => 0xFF6BD6,
                'footer' => ['text' => "Waifu Analytics · last {$intervalMinutes} min · {$sinceLabel}"],
                'fields' => [
                    ['name' => 'Total buys', 'value' => (string) $total, 'inline' => true],
                    ['name' => 'Players', 'value' => (string) count($purchasesByPlayer), 'inline' => true],
                ],
            ]],
        ];

        return $this->post($payload);
    }

    public function post(array $payload): bool
    {
        if (!$this->isConfigured()) {
            return false;
        }
        $body = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $ch = curl_init($this->webhookUrl);
        curl_setopt_array($ch, [
            CURLOPT_POST => true,
            CURLOPT_HTTPHEADER => ['Content-Type: application/json'],
            CURLOPT_POSTFIELDS => $body,
            CURLOPT_RETURNTRANSFER => true,
            CURLOPT_TIMEOUT => 15,
        ]);
        $response = curl_exec($ch);
        $code = (int) curl_getinfo($ch, CURLINFO_HTTP_CODE);
        curl_close($ch);
        return $code >= 200 && $code < 300;
    }
}
