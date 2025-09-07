<?php

namespace Webkul\Theme;

use Illuminate\Support\Arr;
use Illuminate\Support\Str;
use Illuminate\View\FileViewFinder;
use Webkul\Theme\Facades\Themes;

class ThemeViewFinder extends FileViewFinder
{
    public const ADMIN_PACKAGE_VIEWS_NAMESPACE = 'admin';
    public const SHOP_PACKAGE_VIEWS_NAMESPACE = 'shop';

    protected function findNamespacedView($name)
    {
        [$namespace, $view] = $this->parseNamespaceSegments($name);

        $isAdmin = Str::contains(request()->url(), config('app.admin_url').'/' );

        $this->setActiveTheme($isAdmin);

        $paths = $this->addThemeNamespacePaths($namespace);

        try {
            return $this->findInPaths($view, $paths);
        } catch (\Exception $e) {
            $view = $this->getThemedViewName($namespace, $view, $isAdmin);

            return $this->findInPaths($view, $paths);
        }
    }

    protected function setActiveTheme(bool $isAdmin)
    {
        if ($isAdmin) {
            themes()->set(config('themes.admin-default'));
        } else {
            // Set a default shop theme if none is set
            themes()->set(config('themes.shop-default'));
        }
    }

    protected function getThemedViewName($namespace, $view, $isAdmin)
    {
        $theme = themes()->current();
        $themeCode = $theme ? $theme->code : 'default';

        if (!$isAdmin && $namespace !== self::SHOP_PACKAGE_VIEWS_NAMESPACE && Str::contains($view, 'shop.')) {
            return Str::replaceFirst('shop.', "shop.$themeCode.", $view);
        }

        if ($isAdmin && $namespace !== self::ADMIN_PACKAGE_VIEWS_NAMESPACE && Str::contains($view, 'admin.')) {
            return Str::replaceFirst('admin.', "admin.$themeCode.", $view);
        }

        return $view;
    }

    public function addThemeNamespacePaths($namespace)
    {
        if (! isset($this->hints[$namespace])) {
            return [];
        }

        $paths = [];
        $theme = themes()->current();

        if ($theme && $theme->code !== 'default' && in_array($namespace, [
            self::SHOP_PACKAGE_VIEWS_NAMESPACE,
            self::ADMIN_PACKAGE_VIEWS_NAMESPACE,
        ])) {
            $themeNamespace = $theme->viewsNamespace ?? $theme->code;

            if (isset($this->hints[$themeNamespace])) {
                $paths = [...$this->hints[$themeNamespace]];
            }
        }

        $paths = [...$paths, ...$this->hints[$namespace]];

        $searchPaths = array_diff($this->paths, Themes::getLaravelViewPaths());

        foreach (array_reverse($searchPaths) as $path) {
            $paths = Arr::prepend($paths, base_path($path));
        }

        return $paths;
    }

    public function replaceNamespace($namespace, $hints)
    {
        $this->hints[$namespace] = (array) $hints;

        if (in_array($namespace, ['errors', 'mails'])) {
            $searchPaths = array_diff($this->paths, Themes::getLaravelViewPaths());
            $addPaths = array_map(fn($path) => base_path("$path/$namespace"), $searchPaths);
            $this->prependNamespace($namespace, $addPaths);
        }
    }

    public function setPaths($paths)
    {
        $this->paths = $paths;
        $this->flush();
    }
}
