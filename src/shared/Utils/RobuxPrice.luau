local MarketplaceService = game:GetService("MarketplaceService")

export type Item = {
	Product: number?,
	Gamepass: number?,
	Price: number?,
}

local Cache: { [string]: number } = {}

return function(Item: Item): number?
	local Gamepass = Item.Gamepass
	local Id = Gamepass or Item.Product
	if Id == 0 then
		return Item.Price
	end
	local Key = (if Gamepass then "Gamepass" else "Product") .. Id
	if not Cache[Key] then
		local Success, Info = pcall(
			MarketplaceService.GetProductInfo,
			MarketplaceService,
			Id,
			if Gamepass then Enum.InfoType.GamePass else Enum.InfoType.Product
		)
		if not Success or not Info.PriceInRobux then
			return Item.Price
		end
		Cache[Key] = Info.PriceInRobux
	end
	return Cache[Key]
end
